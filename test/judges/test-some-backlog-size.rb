# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'fbe/fb'
require 'judges/options'
require 'loog'
require_relative '../test__helper'

require_relative '../../judges/quality-of-service/some_backlog_size'

class TestSomeBacklogSize < Jp::Test
  def test_samples_as_many_days_as_configured
    fb = Factbase.new
    pmp = fb.insert
    pmp.what = 'pmp'
    pmp.area = 'quality'
    pmp.qos_backlog_days = 3
    fact = fb.insert
    fact.since = Time.parse('2025-01-01 00:00:00 UTC')
    fact.when = Time.parse('2025-01-10 00:00:00 UTC')
    $judge = 'quality-of-service'
    $loog = Loog::NULL
    $global = {}
    $options = Judges::Options.new({ 'repositories' => 'foo/foo' })
    octo = Object.new
    octo.define_singleton_method(:off_quota?) { |**| false }
    result =
      Fbe.stub(:fb, fb) do
        Fbe.stub(:octo, octo) do
          Fbe.stub(:unmask_repos, proc { |&b| b.call('foo/foo') }) do
            Jp.stub(:qosearch, { total_count: 4 }) { some_backlog_size(fact) }
          end
        end
      end
    assert_equal([4, 4, 4], result[:some_backlog_size])
  end

  def test_uses_default_sample_when_fbe_raises
    fact = Factbase.new.insert
    pmp = Object.new
    pmp.define_singleton_method(:quality) { pmp }
    pmp.define_singleton_method(:qos_backlog_days) do
      raise(Fbe::Error, "There is no 'qos_backlog_days' property in the 'quality' area")
    end
    octo = Object.new
    octo.define_singleton_method(:off_quota?) { |**| false }
    result =
      Fbe.stub(:pmp, pmp) do
        Fbe.stub(:octo, octo) do
          Fbe.stub(:unmask_repos, proc { |&b| }) do
            some_backlog_size(fact)
          end
        end
      end
    assert_equal({ some_backlog_size: [] }, result)
  end
end
