# frozen_string_literal: true

# MIT License
#
# Copyright (c) 2024-2025 Zerocracy
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

require 'factbase'
require 'loog'
require 'json'
require 'minitest/autorun'
require 'webmock/minitest'
require 'judges/options'

# Test.
class TestFindAllIssues < Minitest::Test
  def test_find_all_issues_without_issues_in_fb
    WebMock.disable_net_connect!
    stub_github(
      'https://api.github.com/repos/foo/foo',
      body: { id: 695, name: 'foo', full_name: 'foo/foo', created_at: Time.parse('2024-07-11 20:35:25 UTC') }
    )
    fb = Factbase.new
    load_it('find-all-issues', fb)
    fs = fb.query('(always)').each.to_a
    assert_equal(1, fs.count)
    fs.first.then do |f|
      assert_equal('min-issue-was-found', f.what)
      assert_equal('github', f.where)
      assert_equal(695, f.repository)
      assert_equal(0, f.latest)
    end
    assert_empty(fb.query("(eq what 'issue-was-opened')").each.to_a)
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
    assert_equal(2, fs.count)
    fs.last.then do |f|
      assert_equal('min-issue-was-found', f.what)
      assert_equal('github', f.where)
      assert_equal(695, f.repository)
      assert_equal(0, f.latest)
    end
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
        resources: { core: { limit: 60, remaining: 59, reset: 1_728_464_472, used: 1, resource: 'core' } },
        rate: { limit: 60, remaining: 59, reset: 1_728_464_472, used: 1, resource: 'core' }
      }
    )
    stub_github(
      'https://api.github.com/search/issues?per_page=100&q=repo:foo/foo%20type:issue%20created:%3C=2024-09-10',
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
    assert_equal(6, fb.query('(always)').each.to_a.count)
    fb.query("(eq what 'min-issue-was-found')").each.to_a.first.then do |f|
      assert_equal('min-issue-was-found', f.what)
      assert_equal('github', f.where)
      assert_equal(695, f.repository)
      assert_equal(87, f.latest)
    end
    fs = fb.query("(eq what 'issue-was-opened')").each.to_a
    assert_equal(5, fs.count)
    fs[-2].then do |f|
      assert_nil(f[:event_id])
      assert_nil(f[:event_type])
      assert_equal('The issue foo/foo#42 has been opened by @yegor256.', f.details)
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
      assert_equal('The issue foo/foo#45 has been opened by @yegor257.', f.details)
      assert_equal(45, f.issue)
      assert_equal(695, f.repository)
      assert_equal('issue-was-opened', f.what)
      assert_equal(Time.parse('2024-09-04 18:00:00 UTC'), f.when)
      assert_equal('github', f.where)
      assert_equal(526_302, f.who)
    end
  end
end
