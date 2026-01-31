# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../test__helper'

# Test.
class TestFindLatestIssue < Jp::Test
  using SmartFactbase

  def test_find_latest_issue
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github(
      'https://api.github.com/repos/foo/foo', body: { id: 42, name: 'foo', full_name: 'foo/foo' }
    )
    stub_github(
      'https://api.github.com/repositories/42', body: { id: 42, name: 'foo', full_name: 'foo/foo' }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/issues?direction=desc&page=1&per_page=1&sort=created&state=all',
      body: [
        {
          id: 123,
          number: 547,
          title: 'Some title',
          user: { id: 44, login: 'user' },
          created_at: '2025-09-14 20:03:16 UTC'
        }
      ]
    )
    stub_github('https://api.github.com/user/44', body: { id: 44, login: 'user' })
    fb = Factbase.new
    load_it('find-latest-issue', fb)
    assert_equal(2, fb.all.size)
    assert(
      fb.one?(
        what: 'issue-was-opened', issue: 547, repository: 42, where: 'github',
        who: 44, when: Time.parse('2025-09-14 20:03:16 UTC'),
        details: 'The issue foo/foo#547 is the first we found, opened by @user.'
      )
    )
    assert(fb.one?(what: 'iterate', latest_issue_was_found: 547, repository: 42, where: 'github'))
  end

  def test_find_latest_pull
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github(
      'https://api.github.com/repos/foo/foo', body: { id: 42, name: 'foo', full_name: 'foo/foo' }
    )
    stub_github(
      'https://api.github.com/repositories/42', body: { id: 42, name: 'foo', full_name: 'foo/foo' }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/issues?direction=desc&page=1&per_page=1&sort=created&state=all',
      body: [
        {
          id: 123,
          number: 548,
          title: 'Some title',
          user: { id: 44, login: 'user' },
          pull_request: { merged_at: '2025-09-14 20:03:16 UTC' },
          created_at: '2025-09-14 20:03:16 UTC'
        }
      ]
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/548',
      body: {
        id: 1234,
        number: 548,
        head: { ref: '547' }
      }
    )
    stub_github('https://api.github.com/user/44', body: { id: 44, login: 'user' })
    fb = Factbase.new
    load_it('find-latest-issue', fb)
    assert_equal(2, fb.all.size)
    assert(
      fb.one?(
        what: 'pull-was-opened', issue: 548, repository: 42, where: 'github',
        who: 44, branch: '547', when: Time.parse('2025-09-14 20:03:16 UTC'),
        details: 'The issue foo/foo#548 is the first we found, opened by @user.'
      )
    )
    assert(fb.one?(what: 'iterate', latest_issue_was_found: 548, repository: 42, where: 'github'))
  end

  def test_not_found_latest_issue
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github(
      'https://api.github.com/repos/foo/foo', body: { id: 42, name: 'foo', full_name: 'foo/foo' }
    )
    stub_github(
      'https://api.github.com/repositories/42', body: { id: 42, name: 'foo', full_name: 'foo/foo' }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/issues?direction=desc&page=1&per_page=1&sort=created&state=all',
      body: []
    )
    fb = Factbase.new
    load_it('find-latest-issue', fb)
    assert_equal(0, fb.all.size)
  end

  def test_if_latest_issue_exist
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github(
      'https://api.github.com/repos/foo/foo', body: { id: 42, name: 'foo', full_name: 'foo/foo' }
    )
    stub_github(
      'https://api.github.com/repositories/42', body: { id: 42, name: 'foo', full_name: 'foo/foo' }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/issues?direction=desc&page=1&per_page=1&sort=created&state=all',
      body: [
        {
          id: 123,
          number: 547,
          title: 'Some title',
          user: { id: 44, login: 'user' },
          created_at: '2025-09-14 20:03:16 UTC'
        }
      ]
    )
    fb = Factbase.new
    fb.with(
      _id: 1, what: 'issue-was-opened', issue: 547, repository: 42, where: 'github',
      who: 44, when: Time.parse('2025-09-14 20:03:16 UTC'),
      details: 'The issue foo/foo#547 has been opened by @user.'
    )
    load_it('find-latest-issue', fb)
    assert_equal(2, fb.all.size)
    assert(
      fb.one?(
        _id: 1, what: 'issue-was-opened', issue: 547, repository: 42, where: 'github',
        who: 44, when: Time.parse('2025-09-14 20:03:16 UTC'),
        details: 'The issue foo/foo#547 has been opened by @user.'
      )
    )
    assert(fb.one?(what: 'iterate', latest_issue_was_found: 547, repository: 42, where: 'github'))
  end

  def test_if_find_latest_issue_already_found
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github(
      'https://api.github.com/repos/foo/foo', body: { id: 42, name: 'foo', full_name: 'foo/foo' }
    )
    fb = Factbase.new
    fb.with(
      _id: 1, what: 'issue-was-opened', issue: 547, repository: 42, where: 'github',
      who: 44, when: Time.parse('2025-09-14 20:03:16 UTC'),
      details: 'The issue foo/foo#547 has been opened by @user.'
    ).with(
      _id: 2, what: 'iterate', where: 'github', repository: 42, latest_issue_was_found: 547
    )
    load_it('find-latest-issue', fb)
    assert_equal(2, fb.all.size)
    assert(fb.one?(what: 'iterate', latest_issue_was_found: 547, repository: 42, where: 'github'))
  end
end
