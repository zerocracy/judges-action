# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'judges/options'
require 'loog'
require_relative '../test__helper'

require_relative '../../judges/quality-of-service/some_merged_pulls'

class TestSomeMergedPulls < Jp::Test
  def test_keeps_the_counts_of_a_repository_when_a_later_search_fails
    fact = Factbase.new.insert
    fact.since = Time.parse('2025-01-01 00:00:00 UTC')
    fact.when = Time.parse('2025-02-01 00:00:00 UTC')
    $judge = 'quality-of-service'
    $loog = Loog::NULL
    $global = {}
    $options = Judges::Options.new({ 'repositories' => 'foo/foo,foo/bar' })
    octo = Object.new
    octo.define_singleton_method(:off_quota?) { |**| false }
    answers = [{ total_count: 10 }, { total_count: 3 }, nil]
    result =
      Fbe.stub(:octo, octo) do
        Fbe.stub(:unmask_repos, proc { |&b| %w[foo/foo foo/bar].each(&b) }) do
          Jp.stub(:qosearch, proc { |*| answers.shift }) { some_merged_pulls(fact) }
        end
      end
    assert_equal({ some_merged_pulls: [10], some_unmerged_pulls: [3] }, result)
  end

  def test_stops_before_the_next_repository_when_the_quota_is_gone
    calls = 0
    result, searches = run_metric(
      repos: %w[foo/foo foo/bar],
      answers: [{ total_count: 10 }, { total_count: 3 }, { total_count: 20 }, { total_count: 4 }],
      quota: proc { |**| (calls += 1) == 3 }
    )
    assert_equal({ some_merged_pulls: [10], some_unmerged_pulls: [3] }, result)
    assert_equal(2, searches.size, 'no search may run in foo/bar after the quota is gone')
  end

  def test_stops_between_the_merged_and_unmerged_search_when_the_quota_is_gone
    calls = 0
    result, searches = run_metric(
      repos: %w[foo/foo],
      answers: [{ total_count: 10 }, { total_count: 3 }],
      quota: proc { |**| (calls += 1) == 2 }
    )
    assert_equal({ some_merged_pulls: [], some_unmerged_pulls: [] }, result)
    assert_equal(1, searches.size, 'no unmerged search may run after the quota is gone')
  end

  def test_keeps_the_counts_when_only_the_merged_search_fails
    result, = run_metric(repos: %w[foo/foo foo/bar], answers: [nil, { total_count: 20 }, { total_count: 4 }])
    assert_equal({ some_merged_pulls: [20], some_unmerged_pulls: [4] }, result)
  end

  def test_keeps_the_counts_when_only_the_unmerged_search_fails
    result, = run_metric(
      repos: %w[foo/foo foo/bar],
      answers: [{ total_count: 10 }, nil, { total_count: 20 }, { total_count: 4 }]
    )
    assert_equal({ some_merged_pulls: [20], some_unmerged_pulls: [4] }, result)
  end

  private

  def run_metric(repos:, answers:, quota: proc { |**| false })
    fact = Factbase.new.insert
    fact.since = Time.parse('2025-01-01 00:00:00 UTC')
    fact.when = Time.parse('2025-02-01 00:00:00 UTC')
    $judge = 'quality-of-service'
    $loog = Loog::NULL
    $global = {}
    $options = Judges::Options.new({ 'repositories' => repos.join(',') })
    octo = Object.new
    octo.define_singleton_method(:off_quota?, &quota)
    searches = []
    result =
      Fbe.stub(:octo, octo) do
        Fbe.stub(:unmask_repos, proc { |&b| repos.each(&b) }) do
          Jp.stub(
            :qosearch,
            proc do |q, **|
              searches << q
              answers.shift
            end
          ) { some_merged_pulls(fact) }
        end
      end
    [result, searches]
  end
end
