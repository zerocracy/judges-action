# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../../judges/quality-of-service/some_release_hoc_size'
require_relative '../../judges/quality-of-service/some_release_interval'
require_relative '../test__helper'

class TestReleaseWindow < Jp::Test
  def test_intervals_include_releases_after_an_old_release_and_on_later_pages
    fact = release_window
    assert_equal([86_400, 86_400], some_release_interval(fact)[:some_release_interval])
  end

  def test_compares_in_window_releases_in_publication_order
    fact = release_window
    stub_github(
      'https://api.github.com/repos/foo/foo/compare/first...second?per_page=100',
      body: { files: [{ changes: 3 }], total_commits: 1 }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/compare/second...third?per_page=100',
      body: { files: [{ changes: 7 }], total_commits: 2 }
    )
    assert_equal({ some_release_hoc_size: [3, 7], some_release_commits_size: [1, 2] }, some_release_hoc_size(fact))
  end

  private

  def release_window
    WebMock.disable_net_connect!
    rate_limit_up
    $global = {}
    $loog = Loog::NULL
    $options = Judges::Options.new({ 'repositories' => 'foo/foo' })
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/repos/foo/foo/releases?per_page=100',
      body: [
        { tag_name: 'old', published_at: Time.utc(2024, 8, 1), created_at: Time.utc(2024, 7, 6) },
        { tag_name: 'future', published_at: Time.utc(2024, 8, 5), created_at: Time.utc(2024, 7, 5) },
        { tag_name: 'draft', published_at: nil, created_at: Time.utc(2024, 7, 4) }
      ],
      headers: {
        'Content-Type' => 'application/json',
        'X-RateLimit-Remaining' => '999',
        'Link' => '<https://api.github.com/repos/foo/foo/releases?page=2&per_page=100>; rel="next"'
      }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/releases?page=2&per_page=100',
      body: [
        { tag_name: 'third', published_at: Time.utc(2024, 8, 4), created_at: Time.utc(2024, 7, 3) },
        { tag_name: 'first', published_at: Time.utc(2024, 8, 2), created_at: Time.utc(2024, 7, 2) },
        { tag_name: 'second', published_at: Time.utc(2024, 8, 3), created_at: Time.utc(2024, 7, 1) }
      ]
    )
    fact = Factbase.new.insert
    fact.since = Time.utc(2024, 8, 2)
    fact.when = Time.utc(2024, 8, 4)
    fact
  end
end
