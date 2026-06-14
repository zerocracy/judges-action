# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../../lib/fill_fact'
require_relative '../test__helper'

class TestFillFact < Minitest::Test
  def test_empty_hash_leaves_fact_untouched
    fb = Factbase.new
    fact = fb.insert
    fact.what = 'seed'
    Jp.fill_fact_by_hash(fact, {})
    assert_equal('seed', fact.what)
    assert_equal(%w[what], fact.all_properties)
  end

  def test_multi_key_hash_sets_every_property
    fb = Factbase.new
    fact = fb.insert
    Jp.fill_fact_by_hash(fact, { what: 'pull-was-merged', issue: 7, repository: 42 })
    assert_equal('pull-was-merged', fact.what)
    assert_equal(7, fact.issue)
    assert_equal(42, fact.repository)
  end

  def test_symbol_and_string_keys_resolve_to_same_setter
    fb = Factbase.new
    sym = fb.insert
    str = fb.insert
    Jp.fill_fact_by_hash(sym, { who: 888 })
    Jp.fill_fact_by_hash(str, { 'who' => 888 })
    assert_equal(888, sym.who)
    assert_equal(888, str.who)
    assert_equal(sym.all_properties, str.all_properties)
  end

  def test_nil_value_raises_through_factbase_setter
    fb = Factbase.new
    fact = fb.insert
    assert_raises(RuntimeError) { Jp.fill_fact_by_hash(fact, { who: nil }) }
  end
end
