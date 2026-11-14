# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'fbe/fb'
require 'fbe/pmp'
require 'judges/options'
require 'loog'
require_relative '../test__helper'

require_relative '../../lib/qos_param'

class TestQosParam < Jp::Test
  def setup
    super
    $global = {}
    $options = Judges::Options.new({})
    $loog = Loog::NULL
  end

  def test_reads_the_value_from_the_pmp_fact
    fb = Factbase.new
    pmp = fb.insert
    pmp.what = 'pmp'
    pmp.area = 'quality'
    pmp.qos_backlog_days = 3
    Fbe.stub(:fb, fb) do
      assert_equal(3, Jp.qos_param(:qos_backlog_days, 7))
    end
  end

  def test_uses_default_when_fbe_raises
    pmp = Object.new
    pmp.define_singleton_method(:quality) { pmp }
    pmp.define_singleton_method(:qos_pause_seconds) do
      raise(Fbe::Error, "There is no 'qos_pause_seconds' property in the 'quality' area")
    end
    Fbe.stub(:pmp, pmp) do
      assert_equal(0, Jp.qos_param(:qos_pause_seconds, 0))
    end
  end

  def test_uses_default_when_fbe_returns_nil
    Fbe.stub(:fb, Factbase.new) do
      assert_equal(7, Jp.qos_param(:qos_backlog_days, 7))
    end
  end

  def test_returns_nil_when_no_default_is_given
    Fbe.stub(:fb, Factbase.new) do
      assert_nil(Jp.qos_param(:qos_max_per_fact))
    end
  end
end
