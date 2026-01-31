# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'json'
require 'judges/options'
require 'loog'
require_relative '../test__helper'

# Test.
class TestFindAllIssues < Jp::Test
  def test_find_all_issues_without_issues_in_fb
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github(
      'https://api.github.com/repos/foo/foo',
      body: { id: 695, name: 'foo', full_name: 'foo/foo', created_at: Time.parse('2024-07-11 20:35:25 UTC') }
    )
    fb = Factbase.new
    load_it('find-all-issues', fb)
    fs = fb.query('(always)').each.to_a
    assert_equal(0, fs.count)
    assert_empty(fb.query("(eq what 'issue-was-opened')").each.to_a)
  end

  def test_restores_one_missing_fact
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 991 })
    stub_github('https://api.github.com/repositories/991', body: { full_name: 'foo/foo' })
    stub_github('https://api.github.com/repos/foo/foo/issues/45', body: { created_at: Time.parse('2025-05-04') })
    stub_github(
      'https://api.github.com/search/issues?per_page=100&q=repo:foo/foo%20type:issue%20created:%3E=2025-05-04',
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
      f.repository = 991
      f.what = 'issue-was-opened'
      f.where = 'github'
    end
    load_it('find-all-issues', fb)
    assert_equal(3, fb.size)
    refute_empty(fb.query('(eq issue 46)').each.to_a)
  end

  def test_restarts_after_zero
    WebMock.disable_net_connect!
    fb = Factbase.new
    fb.insert.then do |f|
      f._id = 10
      f.issue = 880
      f.repository = 1579
      f.what = 'issue-was-opened'
      f.where = 'github'
    end
    fb.insert.then do |f|
      f._id = 11
      f.what = 'iterate'
      f.min_issue_was_found = 0
      f.where = 'github'
      f.repository = 1579
    end
    load_it('find-all-issues', fb, Judges::Options.new({ 'testing' => true, 'repositories' => 'yegor256/factbase' }))
    assert_equal(3, fb.size)
  end

  def test_find_all_issues_with_not_found_min_issue_in_github
    WebMock.disable_net_connect!
    stub_github(
      'https://api.github.com/repos/foo/foo',
      body: { id: 695, name: 'foo', full_name: 'foo/foo', created_at: Time.parse('2024-07-11 20:35:25 UTC') }
    )
    stub_github(
      'https://api.github.com/repositories/695',
      body: { id: 695, name: 'foo', full_name: 'foo/foo', created_at: Time.parse('2024-07-11 20:35:25 UTC') }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/issues/87',
      status: 404,
      body: { message: 'Not Found', documentation_url: 'https://docs.github.com', status: '404' }
    )
    stub_github(
      'https://api.github.com/rate_limit',
      body: {
        resources: { core: { limit: 60, remaining: 59, reset: 1_728_464_472, used: 1, resource: 'core' } },
        rate: { limit: 60, remaining: 59, reset: 1_728_464_472, used: 1, resource: 'core' }
      }
    )
    fb = Factbase.new
    fb.insert.then do |f|
      f.details = 'The issue foo/foo#87 has been opened by @bar.'
      f.event_id = 1_598_476_635
      f.event_type = 'IssuesEvent'
      f.is_human = 1
      f.issue = 87
      f.repository = 695
      f.what = 'issue-was-opened'
      f.when = Time.parse('2024-09-10T15:00:00Z')
      f.where = 'github'
      f.who = 257_964
    end
    load_it('find-all-issues', fb)
    fs = fb.query('(always)').each.to_a
    assert_equal(1, fs.count)
    refute_empty(fb.query("(eq what 'issue-was-opened')").each.to_a)
  end

  def test_find_all_issues
    WebMock.disable_net_connect!
    stub_github(
      'https://api.github.com/repos/foo/foo',
      body: { id: 695, name: 'foo', full_name: 'foo/foo', created_at: Time.parse('2024-07-11 20:35:25 UTC') }
    )
    stub_github(
      'https://api.github.com/repositories/695',
      body: { id: 695, name: 'foo', full_name: 'foo/foo', created_at: Time.parse('2024-07-11 20:35:25 UTC') }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/issues/87',
      body: {
        id: 2_564_855_709, number: 87, title: 'Issue 87', created_at: Time.parse('2024-09-10 15:00:00 UTC')
      }
    )
    stub_github(
      'https://api.github.com/rate_limit',
      body: {
        resources: { core: { limit: 999, remaining: 999, reset: 1_728_464_472, used: 1, resource: 'core' } },
        rate: { limit: 999, remaining: 999, reset: 1_728_464_472, used: 1, resource: 'core' }
      }
    )
    stub_github(
      %r{https://api\.github\.com/search/issues\?.*},
      body: {
        total_count: 3, incomplete_results: false,
        items: [
          {
            id: 2_544_140_680, number: 42, title: 'Issue 42',
            user: { login: 'yegor256', id: 526_301, type: 'User', site_admin: false },
            created_at: Time.parse('2024-09-04 17:00:00 UTC')
          },
          {
            id: 2_544_140_685, number: 45, title: 'Issue 45',
            user: { login: 'yegor257', id: 526_302, type: 'User', site_admin: false },
            created_at: Time.parse('2024-09-04 18:00:00 UTC')
          },
          {
            id: 2_564_855_709, number: 87, title: 'Issue 87',
            user: { login: 'bar', id: 257_964, type: 'User', site_admin: false },
            created_at: Time.parse('2024-09-10 15:00:00 UTC')
          }
        ]
      }
    )
    stub_github(
      'https://api.github.com/user/526301',
      body: { login: 'yegor256', id: 526_301, type: 'User', site_admin: false }
    )
    stub_github(
      'https://api.github.com/user/526302',
      body: { login: 'yegor257', id: 526_301, type: 'User', site_admin: false }
    )
    fb = Factbase.new
    fb.insert.then do |f|
      f.details = 'The issue foo/foo#87 has been opened by @bar.'
      f.event_id = 1_598_476_635
      f.event_type = 'IssuesEvent'
      f.is_human = 1
      f.issue = 87
      f.repository = 695
      f.what = 'issue-was-opened'
      f.when = Time.parse('2024-09-10T15:00:00Z')
      f.where = 'github'
      f.who = 257_964
    end
    fb.insert.then do |f|
      f.issue = 85
      f.repository = 700
      f.what = 'issue-was-opened'
      f.when = Time.parse('2024-09-09T15:00:00Z')
      f.where = 'github'
      f.who = 257_961
    end
    fb.insert.then do |f|
      f.issue = 85
      f.repository = 695
      f.what = 'issue-was-opened'
      f.when = Time.parse('2024-09-08T15:00:00Z')
      f.where = 'gitlab'
      f.who = 257_962
    end
    load_it('find-all-issues', fb)
    assert_equal(6, fb.query('(always)').each.to_a.size)
    fb.query("(eq what 'iterate')").each.first.then do |f|
      assert_equal('github', f.where)
      assert_equal(695, f.repository)
      assert_equal(87, f.min_issue_was_found)
    end
    fs = fb.query("(eq what 'issue-was-opened')").each.to_a
    assert_equal(5, fs.count)
    fs[-2].then do |f|
      assert_nil(f[:event_id])
      assert_nil(f[:event_type])
      assert_equal('The issue foo/foo#42 has been earlier opened by @yegor256.', f.details)
      assert_equal(42, f.issue)
      assert_equal(695, f.repository)
      assert_equal('issue-was-opened', f.what)
      assert_equal(Time.parse('2024-09-04 17:00:00 UTC'), f.when)
      assert_equal('github', f.where)
      assert_equal(526_301, f.who)
    end
    fs[-1].then do |f|
      assert_nil(f[:event_id])
      assert_nil(f[:event_type])
      assert_equal('The issue foo/foo#45 has been earlier opened by @yegor257.', f.details)
      assert_equal(45, f.issue)
      assert_equal(695, f.repository)
      assert_equal('issue-was-opened', f.what)
      assert_equal(Time.parse('2024-09-04 18:00:00 UTC'), f.when)
      assert_equal('github', f.where)
      assert_equal(526_302, f.who)
    end
  end

  def test_end_of_iteration_leave_old_marker_instead_reset_to_zero
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 991 })
    stub_github('https://api.github.com/repositories/991', body: { full_name: 'foo/foo' })
    stub_github('https://api.github.com/repos/foo/foo/issues/45', body: { created_at: Time.parse('2025-05-04') })
    stub_github(
      'https://api.github.com/search/issues?per_page=100&q=repo:foo/foo%20type:issue%20created:%3E=2025-05-04',
      body: {
        total_count: 2, incomplete_results: false,
        items: [{ number: 45, created_at: Time.parse('2025-05-04'), user: { id: 4242 } }]
      }
    )
    stub_github('https://api.github.com/user/4242', body: { login: 'yegor256' })
    fb = Factbase.new
    fb.insert.then do |f|
      f._id = 1
      f.repository = 991
      f.what = 'iterate'
      f.where = 'github'
      f.min_issue_was_found = 44
    end
    fb.insert.then do |f|
      f._id = 2
      f.issue = 44
      f.repository = 991
      f.what = 'issue-was-opened'
      f.where = 'github'
    end
    fb.insert.then do |f|
      f._id = 3
      f.issue = 45
      f.repository = 991
      f.what = 'issue-was-opened'
      f.where = 'github'
    end
    load_it('find-all-issues', fb)
    assert_equal(3, fb.size)
    refute_equal(0, fb.query('(eq what "iterate")').each.to_a.first.min_issue_was_found)
    assert_equal(45, fb.query('(eq what "iterate")').each.to_a.first.min_issue_was_found)
  end

  def test_when_issue_response_has_empty_created_at
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 991 })
    stub_github('https://api.github.com/repositories/991', body: { full_name: 'foo/foo' })
    stub_github('https://api.github.com/repos/foo/foo/issues/11', body: { created_at: nil })
    fb = Factbase.new
    fb.insert.then do |f|
      f._id = 1
      f.repository = 991
      f.what = 'iterate'
      f.where = 'github'
      f.min_issue_was_found = 5
    end
    fb.insert.then do |f|
      f._id = 2
      f.issue = 11
      f.repository = 991
      f.what = 'issue-was-opened'
      f.where = 'github'
    end
    load_it('find-all-issues', fb)
    assert_equal(2, fb.size)
    assert_equal(5, fb.query('(eq what "iterate")').each.to_a.first.min_issue_was_found)
  end
end
