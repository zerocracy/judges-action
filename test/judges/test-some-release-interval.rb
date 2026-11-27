# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'judges/options'
require 'loog'
require_relative '../fake_github'
require_relative '../test__helper'

require_relative '../../judges/quality-of-service/some_release_interval'

class TestSomeReleaseInterval < Jp::Test
  def test_measures_gaps_between_releases_of_one_repository
    seed = Random.new_seed
    random = Random.new(seed)
    gap = random.rand(600..86_400)
    shift = random.rand(1...gap)
    base = Time.parse('2024-08-10 00:00:00 UTC')
    foo = [{ id: 2, published_at: (base + gap).utc.iso8601 }, { id: 1, published_at: base.utc.iso8601 }]
    bar = [
      { id: 4, published_at: (base + shift + gap).utc.iso8601 },
      { id: 3, published_at: (base + shift).utc.iso8601 }
    ]
    fact = Factbase.new.insert
    fact.since = Time.parse('2024-08-01 00:00:00 UTC')
    fact.when = Time.parse('2024-09-01 00:00:00 UTC')
    $global = {}
    $loog = Loog::NULL
    $options = Judges::Options.new({ 'repositories' => 'foo/foo,foo/bar' })
    intervals =
      Jp::FakeGithub.new(
        'GET /rate_limit' => { resources: { search: { remaining: 30, limit: 30 } }, rate: { remaining: 1000 } },
        'GET /repos/foo/foo' => { id: 42, full_name: 'foo/foo' },
        'GET /repos/foo/bar' => { id: 43, full_name: 'foo/bar' },
        'GET /repos/foo/foo/releases?per_page=100' => [200, foo],
        'GET /repos/foo/bar/releases?per_page=100' => [200, bar]
      ).run { some_release_interval(fact)[:some_release_interval] }
    assert_equal(
      [gap, gap], intervals,
      "the intervals #{intervals.inspect} are gaps between releases of different repositories, seed #{seed}"
    )
  end

  def test_skips_repository_with_a_single_release
    seed = Random.new_seed
    random = Random.new(seed)
    gap = random.rand(600..86_400)
    base = Time.parse('2024-08-10 00:00:00 UTC')
    foo = [{ id: 2, published_at: (base + gap).utc.iso8601 }, { id: 1, published_at: base.utc.iso8601 }]
    bar = [{ id: 3, published_at: (base + random.rand(1...gap)).utc.iso8601 }]
    fact = Factbase.new.insert
    fact.since = Time.parse('2024-08-01 00:00:00 UTC')
    fact.when = Time.parse('2024-09-01 00:00:00 UTC')
    $global = {}
    $loog = Loog::NULL
    $options = Judges::Options.new({ 'repositories' => 'foo/foo,foo/bar' })
    intervals =
      Jp::FakeGithub.new(
        'GET /rate_limit' => { resources: { search: { remaining: 30, limit: 30 } }, rate: { remaining: 1000 } },
        'GET /repos/foo/foo' => { id: 42, full_name: 'foo/foo' },
        'GET /repos/foo/bar' => { id: 43, full_name: 'foo/bar' },
        'GET /repos/foo/foo/releases?per_page=100' => [200, foo],
        'GET /repos/foo/bar/releases?per_page=100' => [200, bar]
      ).run { some_release_interval(fact)[:some_release_interval] }
    assert_equal(
      [gap], intervals,
      "the lonely release of foo/bar became an interval #{intervals.inspect}, seed #{seed}"
    )
  end

  def test_counts_a_release_published_long_after_it_was_created
    fact = Factbase.new.insert
    fact.since = Time.parse('2024-08-01 00:00:00 UTC')
    fact.when = Time.parse('2024-09-01 00:00:00 UTC')
    $global = {}
    $loog = Loog::NULL
    $options = Judges::Options.new({ 'repositories' => 'foo/foo' })
    listed = [
      { id: 3, published_at: '2024-07-01T00:00:00Z' },
      { id: 2, published_at: '2024-08-20T00:00:00Z' },
      { id: 1, published_at: '2024-08-10T00:00:00Z' }
    ]
    intervals =
      Jp::FakeGithub.new(
        'GET /rate_limit' => { resources: { search: { remaining: 30, limit: 30 } }, rate: { remaining: 1000 } },
        'GET /repos/foo/foo' => { id: 42, full_name: 'foo/foo' },
        'GET /repos/foo/foo/releases?per_page=100' => [200, listed]
      ).run { some_release_interval(fact)[:some_release_interval] }
    assert_equal([864_000], intervals, 'a release published inside the window after an older one was skipped')
  end
end
