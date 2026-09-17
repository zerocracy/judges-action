# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'judges/options'
require 'loog'
require_relative '../test__helper'

require_relative '../../judges/quality-of-service/some_merged_pulls'

class TestSomeMergedPulls < Jp::Test
  def test_asks_about_the_search_quota
    fact = Factbase.new.insert
    fact.since = Time.parse('2025-01-01 00:00:00 UTC')
    fact.when = Time.parse('2025-02-01 00:00:00 UTC')
    $loog = Loog::NULL
    asked = []
    octo = Object.new
    octo.define_singleton_method(:off_quota?) do |resource: :core, **|
      asked << resource
      false
    end
    found = { total_count: 7, items: [] }
    result =
      Fbe.stub(:octo, octo) do
        Fbe.stub(:unmask_repos, proc { |&b| b.call('foo/foo') }) do
          Jp.stub(:qosearch, found) { some_merged_pulls(fact) }
        end
      end
    assert_equal({ some_merged_pulls: [7], some_unmerged_pulls: [7] }, result)
    assert_equal(%i[search search], asked)
  end
end
