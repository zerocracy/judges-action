# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../../lib/fill_fact'
require_relative '../test__helper'

class TestFillFactValues < Minitest::Test
  def test_writes_an_array_element_by_element
    f = Factbase.new.insert
    Jp.fill_fact_by_hash(f, { 'commits' => [1, 2, 3] })
    assert_equal([1, 2, 3], f['commits'])
  end

  def test_refuses_a_nil_value
    f = Factbase.new.insert
    e = assert_raises(ArgumentError) { Jp.fill_fact_by_hash(f, { 'hoc' => nil }) }
    assert_match(/can't be nil/, e.message)
    assert_match(/hoc/, e.message)
  end

  def test_refuses_a_nil_inside_an_array
    f = Factbase.new.insert
    e = assert_raises(ArgumentError) { Jp.fill_fact_by_hash(f, { 'hoc' => [1, nil] }) }
    assert_match(/can't hold a nil/, e.message)
  end
end
