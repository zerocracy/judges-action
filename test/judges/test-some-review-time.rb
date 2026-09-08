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

  def test_ignores_a_review_submitted_after_the_merge
    assert_empty(review_times(Time.parse('2025-01-10 14:00:00 UTC')))
    assert_empty(review_times(Time.parse('2025-01-11 12:00:00 UTC')))
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
