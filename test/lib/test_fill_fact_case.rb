# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../../lib/fill_fact'
require_relative '../test__helper'

class TestFillFactCase < Jp::Test
  def test_rejects_a_capitalised_property_name
    fb = Factbase.new
    f = fb.insert
    %w[Commits HoC Total_Files].each do |prop|
      assert_includes(
        assert_raises(ArgumentError, "#{prop} must be refused by the guard, not by the factbase") do
          Jp.fill_fact_by_hash(f, { prop => 1 })
        end.message,
        'Invalid property name',
        "the guard let #{prop} through"
      )
    end
  end

  def test_still_takes_a_camel_tail
    fb = Factbase.new
    f = fb.insert
    Jp.fill_fact_by_hash(f, { 'hocTotal' => 3 })
    assert_equal(3, f.hocTotal)
  end
end
