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

  def test_searches_unmerged_pulls_separately
    assert_equal(
      { some_merged_pulls: [140], some_unmerged_pulls: [3] },
      counted(
        'is:unmerged' => { total_count: 3, items: [{ number: 1 }, { number: 2 }, { number: 3 }] },
        'is:merged' => { total_count: 140, items: Array.new(100) { |i| { number: i } } }
      ),
      'The unmerged count must come from its own is:unmerged search'
    )
  end

  def test_reports_total_count_not_the_size_of_one_page
    assert_equal(
      { some_merged_pulls: [250], some_unmerged_pulls: [120] },
      counted(
        'is:unmerged' => { total_count: 120, items: Array.new(100) { |i| { number: i } } },
        'is:merged' => { total_count: 250, items: Array.new(100) { |i| { number: i } } }
      ),
      'A busy repository must not be capped at one page of 100 search items'
    )
  end

  def test_reports_zero_when_no_pull_was_rejected
    assert_equal(
      { some_merged_pulls: [4], some_unmerged_pulls: [0] },
      counted(
        'is:unmerged' => { total_count: 0, items: [] },
        'is:merged' => { total_count: 4, items: Array.new(4) { |i| { number: i } } }
      ),
      'A window with no rejected pulls must report zero, not the merged count'
    )
  end

  private

  def counted(answers)
    fact = Factbase.new.insert
    fact.since = Time.parse('2025-01-01 00:00:00 UTC')
    fact.when = Time.parse('2025-02-01 00:00:00 UTC')
    $judge = 'quality-of-service'
    $loog = Loog::NULL
    $global = {}
    $options = Judges::Options.new({ 'repositories' => 'foo/foo' })
    octo = Object.new
    octo.define_singleton_method(:off_quota?) { |**| false }
    search = proc { |q| answers.find { |k, _| q.include?(" #{k} ") }&.last }
    Fbe.stub(:octo, octo) do
      Fbe.stub(:unmask_repos, proc { |&b| b.call('foo/foo') }) do
        Jp.stub(:qosearch, search) { some_merged_pulls(fact) }
      end
    end
  end
end
