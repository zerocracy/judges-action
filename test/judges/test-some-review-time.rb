# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'judges/options'
require 'loog'
require_relative '../fake_github'
require_relative '../test__helper'

require_relative '../../judges/quality-of-service/some_review_time'

class TestSomeReviewTime < Jp::Test
  def test_measures_the_gap_from_the_first_review_to_the_merge
    assert_equal([7200], review_times(Time.parse('2025-01-10 10:00:00 UTC')))
  end

  def test_skips_a_pull_that_is_not_merged
    fact = Factbase.new.insert
    fact.since = Time.parse('2025-01-01 00:00:00 UTC')
    fact.when = Time.parse('2025-02-01 00:00:00 UTC')
    $global = {}
    $loog = Loog::NULL
    $options = Judges::Options.new({ 'repositories' => 'foo/foo' })
    found = { items: [{ id: 1, number: 10, pull_request: {} }] }
    times =
      Jp::FakeGithub.new(
        'GET /rate_limit' => { resources: { search: { remaining: 30, limit: 30 } }, rate: { remaining: 1000 } },
        'GET /repos/foo/foo' => { id: 42, full_name: 'foo/foo' },
        'GET /repos/foo/foo/pulls/10/reviews?per_page=100' =>
          [200, [{ id: 7, user: { id: 1 }, submitted_at: Time.parse('2025-01-10 10:00:00 UTC').utc.iso8601 }]],
        'GET /repos/foo/foo/pulls/10/comments?per_page=100' => [200, []]
      ).run { Jp.stub(:qosearch, found) { some_review_time(fact)[:some_review_time] } }
    assert_empty(times)
  end

  def test_ignores_a_review_submitted_after_the_merge
    assert_empty(review_times(Time.parse('2025-01-10 14:00:00 UTC')))
    assert_empty(review_times(Time.parse('2025-01-11 12:00:00 UTC')))
  end

  def test_some_review_time_searches_each_second_in_one_window_only
    $loog = Loog::NULL
    load(File.join(__dir__, '../../judges/quality-of-service/some_review_time.rb'))
    Jp.qoreset
    queries = []
    octo = Object.new
    octo.define_singleton_method(:off_quota?) { |**| false }
    octo.define_singleton_method(:repo_id_by_name) { |*| 42 }
    octo.define_singleton_method(:rate_limit) { Struct.new(:remaining).new(30) }
    octo.define_singleton_method(:with_disable_auto_paginate) { |&block| block.call(octo) }
    octo.define_singleton_method(:search_issues) do |q, **|
      queries << q
      { total_count: 0, incomplete_results: false, items: [] }
    end
    window = Struct.new(:since, :when)
    Fbe.stub(:octo, octo) do
      Fbe.stub(:unmask_repos, ->(&block) { block.call('foo/foo') }) do
        some_review_time(window.new(Time.parse('2024-08-02T21:00:00Z'), Time.parse('2024-08-09T21:00:00Z')))
        some_review_time(window.new(Time.parse('2024-08-09T21:00:00Z'), Time.parse('2024-08-16T21:00:00Z')))
        some_review_time(window.new(Time.parse('2024-08-16T21:00:00Z'), Time.parse('2024-08-23T21:00:00.700Z')))
      end
    end
    assert_equal(
      [
        'repo:foo/foo type:pr is:merged closed:2024-08-02T21:00:00Z..2024-08-09T20:59:59Z',
        'repo:foo/foo type:pr is:merged closed:2024-08-09T21:00:00Z..2024-08-16T20:59:59Z',
        'repo:foo/foo type:pr is:merged closed:2024-08-16T21:00:00Z..2024-08-23T20:59:59Z'
      ],
      queries
    )
  end

  private

  def review_times(submitted)
    fact = Factbase.new.insert
    fact.since = Time.parse('2025-01-01 00:00:00 UTC')
    fact.when = Time.parse('2025-02-01 00:00:00 UTC')
    $global = {}
    $loog = Loog::NULL
    $options = Judges::Options.new({ 'repositories' => 'foo/foo' })
    found = { items: [{ id: 1, number: 10, pull_request: { merged_at: Time.parse('2025-01-10 12:00:00 UTC') } }] }
    Jp::FakeGithub.new(
      'GET /rate_limit' => { resources: { search: { remaining: 30, limit: 30 } }, rate: { remaining: 1000 } },
      'GET /repos/foo/foo' => { id: 42, full_name: 'foo/foo' },
      'GET /repos/foo/foo/pulls/10/reviews?per_page=100' =>
        [200, [{ id: 7, user: { id: 1 }, submitted_at: submitted.utc.iso8601 }]],
      'GET /repos/foo/foo/pulls/10/comments?per_page=100' => [200, []]
    ).run { Jp.stub(:qosearch, found) { some_review_time(fact)[:some_review_time] } }
  end
end
