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

  def test_keeps_fractional_review_seconds
    assert_equal([1.75], review_times(Time.parse('2025-01-10 11:59:58.25 UTC')))
  end

  def test_samples_boundary_pulls_in_exactly_one_window_including_subsecond_cutoffs
    $judge = 'quality-of-service'
    $loog = Loog::NULL
    $global = {}
    $options = Judges::Options.new({ 'repositories' => 'foo/foo' })
    Jp.qoreset
    closed = {
      1 => Time.parse('2024-08-09T20:59:59Z'),
      2 => Time.parse('2024-08-09T21:00:00Z'),
      3 => Time.parse('2024-08-23T21:00:00Z'),
      4 => Time.parse('2024-08-23T21:00:01Z')
    }
    octo = boundary_octo(closed)
    win = Struct.new(:since, :when)
    results =
      Fbe.stub(:octo, octo) do
        Fbe.stub(:unmask_repos, proc { |&b| b.call('foo/foo') }) do
          [
            some_review_time(win.new(Time.parse('2024-08-02T21:00:00Z'), Time.parse('2024-08-09T21:00:00Z'))),
            some_review_time(win.new(Time.parse('2024-08-09T21:00:00Z'), Time.parse('2024-08-23T21:00:00.700Z'))),
            some_review_time(win.new(Time.parse('2024-08-23T21:00:00.700Z'), Time.parse('2024-08-30T21:00:00Z')))
          ]
        end
      end
    assert_equal([[1], [1, 1], [1]], results.map { |res| res[:some_reviews_per_pull] })
  end

  private

  def boundary_octo(closed)
    octo = Object.new
    octo.define_singleton_method(:off_quota?) { |**| false }
    octo.define_singleton_method(:rate_limit) { Struct.new(:remaining).new(30) }
    octo.define_singleton_method(:with_disable_auto_paginate) { |&b| b.call(octo) }
    octo.define_singleton_method(:search_issues) do |q, **|
      head = Time.parse(q[/closed:(\S+)\.\./, 1])
      tail = Time.parse(q[/closed:\S+\.\.(\S+)/, 1])
      matched = closed.select { |_, at| at.between?(head, tail) }.keys.map { |num| { number: num } }
      { total_count: matched.size, items: matched }
    end
    octo.define_singleton_method(:pull_request_reviews) do |_repo, _num|
      [{ id: 1, user: { id: 7 }, submitted_at: Time.parse('2024-08-01T00:00:00Z') }]
    end
    octo.define_singleton_method(:review_comments) { |_repo, _num| [] }
    octo
  end

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
        [200, [{ id: 7, user: { id: 1 }, submitted_at: submitted.utc.iso8601(3) }]],
      'GET /repos/foo/foo/pulls/10/comments?per_page=100' => [200, []]
    ).run { Jp.stub(:qosearch, found) { some_review_time(fact)[:some_review_time] } }
  end
end
