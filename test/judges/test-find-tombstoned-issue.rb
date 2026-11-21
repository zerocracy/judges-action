# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'fbe/tombstone'
require_relative '../test__helper'

class TestFindTombstonedIssue < Jp::Test
  def test_find_earliest_issue_skips_buried_issue
    assert_skips_buried_first('find-earliest-issue', 'asc')
  end

  def test_find_latest_issue_skips_buried_issue
    assert_skips_buried_first('find-latest-issue', 'desc')
  end

  def test_find_all_issues_skips_buried_issue
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42 })
    stub_github('https://api.github.com/repositories/42', body: { full_name: 'foo/foo' })
    stub_github('https://api.github.com/repos/foo/foo/issues/45', body: { created_at: Time.parse('2025-05-04') })
    stub_github(
      'https://api.github.com/search/issues?order=asc&per_page=100' \
      '&q=repo:foo/foo%20type:issue%20created:%3E=2025-05-04&sort=created',
      body: {
        total_count: 2, incomplete_results: false,
        items: [
          { number: 45, created_at: Time.parse('2025-05-04'), user: { id: 4242 } },
          { number: 46, created_at: Time.parse('2025-05-05'), user: { id: 4242 } }
        ]
      }
    )
    stub_github('https://api.github.com/user/4242', body: { login: 'yegor256' })
    fb = Factbase.new
    fb.insert.then do |f|
      f.issue = 45
      f.repository = 42
      f.what = 'issue-was-opened'
      f.where = 'github'
    end
    Fbe::Tombstone.new(fb:).bury!('github', 42, 46)
    load_it('find-all-issues', fb)
    assert_empty(
      fb.query("(and (eq issue 46) (eq what 'issue-was-opened'))").each.to_a,
      'find-all-issues must not open a fact for an issue buried in the tombstone'
    )
  end

  private

  def assert_skips_buried_first(judge, direction)
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, name: 'foo', full_name: 'foo/foo' })
    stub_github('https://api.github.com/repositories/42', body: { id: 42, name: 'foo', full_name: 'foo/foo' })
    stub_github(
      "https://api.github.com/repos/foo/foo/issues?direction=#{direction}&page=1&per_page=1&sort=created&state=all",
      body: [{ id: 123, number: 3, user: { id: 44, login: 'user' }, created_at: '2025-09-27 05:03:16 UTC' }]
    )
    stub_github('https://api.github.com/user/44', body: { id: 44, login: 'user' })
    fb = Factbase.new
    Fbe::Tombstone.new(fb:).bury!('github', 42, 3)
    load_it(judge, fb)
    assert_empty(
      fb.query("(and (eq issue 3) (eq what 'issue-was-opened'))").each.to_a,
      "#{judge} must not open a fact for an issue buried in the tombstone"
    )
  end
end
