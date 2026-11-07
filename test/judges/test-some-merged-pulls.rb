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

  def test_some_merged_pulls_searches_each_second_in_one_window_only
    $loog = Loog::NULL
    load(File.join(__dir__, '../../judges/quality-of-service/some_merged_pulls.rb'))
    Jp.qoreset
    queries = []
    octo = Object.new
    octo.define_singleton_method(:off_quota?) { |**| false }
    octo.define_singleton_method(:rate_limit) { Struct.new(:remaining).new(30) }
    octo.define_singleton_method(:with_disable_auto_paginate) { |&block| block.call(octo) }
    octo.define_singleton_method(:search_issues) do |q, **|
      queries << q
      { total_count: 0, incomplete_results: false, items: [] }
    end
    window = Struct.new(:since, :when)
    Fbe.stub(:octo, octo) do
      Fbe.stub(:unmask_repos, ->(&block) { block.call('foo/foo') }) do
        some_merged_pulls(window.new(Time.parse('2024-08-02T21:00:00Z'), Time.parse('2024-08-09T21:00:00Z')))
        some_merged_pulls(window.new(Time.parse('2024-08-09T21:00:00Z'), Time.parse('2024-08-16T21:00:00Z')))
        some_merged_pulls(window.new(Time.parse('2024-08-16T21:00:00Z'), Time.parse('2024-08-23T21:00:00.700Z')))
      end
    end
    assert_equal(
      [
        'repo:foo/foo type:pr is:merged closed:2024-08-02T21:00:00Z..2024-08-09T20:59:59Z',
        'repo:foo/foo type:pr is:unmerged closed:2024-08-02T21:00:00Z..2024-08-09T20:59:59Z',
        'repo:foo/foo type:pr is:merged closed:2024-08-09T21:00:00Z..2024-08-16T20:59:59Z',
        'repo:foo/foo type:pr is:unmerged closed:2024-08-09T21:00:00Z..2024-08-16T20:59:59Z',
        'repo:foo/foo type:pr is:merged closed:2024-08-16T21:00:00Z..2024-08-23T20:59:59Z',
        'repo:foo/foo type:pr is:unmerged closed:2024-08-16T21:00:00Z..2024-08-23T20:59:59Z'
      ],
      queries
    )
  end
end
