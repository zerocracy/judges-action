# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../../lib/fill_fact'
require_relative '../test__helper'

class TestFillFact < Minitest::Test
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
    assert_raises(ArgumentError, 'the all_properties name cannot be used, it collides with the fact API') do
      Jp.fill_fact_by_hash(f, { 'all_properties' => 1 })
    end
  end

  def test_rejects_the_forbidden_method_missing_name
    fb = Factbase.new
    f = fb.insert
    assert_raises(ArgumentError, 'the method_missing name cannot be used, it collides with the fact API') do
      Jp.fill_fact_by_hash(f, { 'method_missing' => 1 })
    end
  end

  def test_rejects_a_property_name_with_an_embedded_newline
    fb = Factbase.new
    f = fb.insert
    assert_raises(ArgumentError, 'a name with an embedded newline cannot slip past the validation') do
      Jp.fill_fact_by_hash(f, { "commits\nall_properties" => 1 })
    end
  end
end
