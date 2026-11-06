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

  def test_dont_count_a_deleted_reviewer
    seed = Random.new_seed
    who = Random.new(seed).rand(1..1_000_000)
    assert_equal(
      [1],
      reviewers_per_pull([{ id: 7, user: { id: who } }, { id: 8, user: nil }]),
      "deleted reviewer is counted as a distinct one, seed #{seed}"
    )
  end

  def test_counts_no_reviewer_when_all_of_them_are_deleted
    seed = Random.new_seed
    count = Random.new(seed).rand(1..9)
    assert_equal(
      [0],
      reviewers_per_pull(Array.new(count) { |i| { id: i, user: nil } }),
      "deleted reviewers are counted as present ones, seed #{seed}"
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

  def reviewers_per_pull(reviews)
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
        [200, reviews.map { |r| r.merge(submitted_at: '2025-01-10T10:00:00Z') }],
      'GET /repos/foo/foo/pulls/10/comments?per_page=100' => [200, []]
    ).run { Jp.stub(:qosearch, found) { some_review_time(fact)[:some_reviewers_per_pull] } }
  end
end
