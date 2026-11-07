# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../../lib/fill_fact'
require_relative '../test__helper'

class TestFillFact < Minitest::Test
  def test_preserves_scalar_and_array_timestamps
    stamp = Time.utc(2026, 10, 14, 12, 34, 56)
    [stamp, [stamp]].each do |value|
      fact = Factbase.new.insert
      Jp.fill_fact_by_hash(fact, { 'when' => value })
      assert_equal([stamp], fact['when'])
      assert_instance_of(Time, fact.when)
    end
  end

  def test_sets_a_valid_property
    fb = Factbase.new
    f = fb.insert
    Jp.fill_fact_by_hash(f, { 'commits' => 42 })
    assert_equal(42, f.commits)
  end

  def test_sets_a_property_named_with_digits_and_underscores
    fb = Factbase.new
    f = fb.insert
    Jp.fill_fact_by_hash(f, { 'hoc_2' => 7 })
    assert_equal(7, f.hoc_2)
  end

  def test_rejects_a_property_name_with_a_dash
    fb = Factbase.new
    f = fb.insert
    assert_raises(ArgumentError, 'a property name with a dash cannot be accepted') do
      Jp.fill_fact_by_hash(f, { 'to-master' => 1 })
    end
  end

  def test_rejects_a_property_name_starting_with_a_digit
    fb = Factbase.new
    f = fb.insert
    assert_raises(ArgumentError, 'a property name starting with a digit cannot be accepted') do
      Jp.fill_fact_by_hash(f, { '1st' => 1 })
    end
  end

  def test_rejects_the_forbidden_all_properties_name
    fb = Factbase.new
    f = fb.insert
    ex =
      assert_raises(ArgumentError, 'the all_properties name cannot be used, it collides with the fact API') do
        Jp.fill_fact_by_hash(f, { 'all_properties' => 1 })
      end
    assert_includes(ex.message, 'all_properties')
  end

  def test_rejects_the_forbidden_method_missing_name
    fb = Factbase.new
    f = fb.insert
    ex =
      assert_raises(ArgumentError, 'the method_missing name cannot be used, it collides with the fact API') do
        Jp.fill_fact_by_hash(f, { 'method_missing' => 1 })
      end
    assert_includes(ex.message, 'method_missing')
  end

  def test_rejects_a_property_name_with_an_embedded_newline
    fb = Factbase.new
    f = fb.insert
    assert_raises(ArgumentError, 'a name with an embedded newline cannot slip past the validation') do
      Jp.fill_fact_by_hash(f, { "commits\nall_properties" => 1 })
    end
  end

  def test_rejects_a_nil_fact
    error = assert_raises(ArgumentError) { Jp.fill_fact_by_hash(nil, { 'commits' => 42 }) }
    assert_equal('The fact cannot be nil', error.message)
  end

  def test_rejects_a_nil_fact_with_empty_hash
    error = assert_raises(ArgumentError) { Jp.fill_fact_by_hash(nil, {}) }
    assert_equal('The fact cannot be nil', error.message)
  end

  def test_rejects_a_nil_hash
    fb = Factbase.new
    fact = fb.insert
    error = assert_raises(ArgumentError) { Jp.fill_fact_by_hash(fact, nil) }
    assert_equal('The hash cannot be nil', error.message)
  end

  def test_handles_an_empty_hash_gracefully
    fb = Factbase.new
    fact = fb.insert
    Jp.fill_fact_by_hash(fact, {})
    assert_empty(fact.all_properties)
  end

  def test_sets_properties_from_symbol_keys
    fb = Factbase.new
    fact = fb.insert
    Jp.fill_fact_by_hash(fact, { count: 99 })
    assert_equal(99, fact.count)
  end

  def test_sets_multiple_valid_properties
    fb = Factbase.new
    fact = fb.insert
    Jp.fill_fact_by_hash(fact, { 'first' => 10, 'second' => 20 })
    assert_equal(10, fact.first)
    assert_equal(20, fact.second)
  end

  def test_sets_array_of_numbers_from_symbol_key
    fb = Factbase.new
    fact = fb.insert
    Jp.fill_fact_by_hash(fact, { numbers: [1, 2, 3] })
    assert_equal([1, 2, 3], fact['numbers'])
  end

  def test_sets_string_value_from_symbol_key
    fb = Factbase.new
    fact = fb.insert
    Jp.fill_fact_by_hash(fact, { name: 'alpha' })
    assert_equal('alpha', fact.name)
  end

  def test_rejects_both_nil_fact_and_nil_hash
    error = assert_raises(ArgumentError) { Jp.fill_fact_by_hash(nil, nil) }
    assert_equal('The fact cannot be nil', error.message)
  end
end
