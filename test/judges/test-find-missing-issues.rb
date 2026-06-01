# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../test__helper'

class TestFindMissingIssues < Jp::Test
  using SmartFactbase

  def test_find_missing_issues_if_issue_not_found
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/repos/foo/foo/issues/45',
      status: 404,
      body: { message: 'Not Found', documentation_url: 'https://docs.github.com', status: '404' }
    )
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, issue: 44, where: 'github')
      .with(_id: 2, what: 'issue-was-opened', repository: 42, issue: 46, where: 'github')
    load_it('find-missing-issues', fb)
    assert(fb.one?(what: 'issue-was-lost', where: 'github', issue: 45, repository: 42, stale: 'issue'))
    assert(fb.one?(what: 'tombstone', where: 'github', issues: '45', repository: 42))
  end

  def test_rescues_forbidden_on_issue_lookup
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/repos/foo/foo/issues/45',
      status: 403,
      body: { message: 'Resource not accessible by integration' }
    )
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, issue: 44, where: 'github')
      .with(_id: 2, what: 'issue-was-opened', repository: 42, issue: 46, where: 'github')
    load_it('find-missing-issues', fb)
    refute(
      fb.one?(what: 'issue-was-lost', where: 'github', issue: 45, repository: 42),
      '403 is transient — no issue-was-lost fact must be created; next cycle will retry the issue lookup'
    )
  end

  def test_continues_scan_after_pull_request_not_found
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/repos/foo/foo/issues/45',
      body: {
        number: 45, pull_request: { url: 'https://api.github.com/repos/foo/foo/pulls/45' },
        user: { id: 44, login: 'user' }, created_at: '2025-09-27 06:03:16 UTC'
      }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/45',
      status: 404,
      body: { message: 'Not Found', documentation_url: 'https://docs.github.com', status: '404' }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/issues/46',
      body: {
        number: 46, pull_request: { url: 'https://api.github.com/repos/foo/foo/pulls/46' },
        user: { id: 44, login: 'user' }, created_at: '2025-09-27 06:04:16 UTC'
      }
    )
    stub_github('https://api.github.com/repos/foo/foo/pulls/46', body: { id: 999, number: 46, head: { ref: 'feature-x' } })
    stub_github('https://api.github.com/user/44', body: { id: 44, login: 'user' })
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-opened', repository: 42, issue: 44, where: 'github')
      .with(_id: 2, what: 'pull-was-opened', repository: 42, issue: 47, where: 'github')
    load_it('find-missing-issues', fb)
    assert(
      fb.one?(what: 'pull-was-opened', issue: 46, repository: 42, where: 'github', branch: 'feature-x'),
      'pull #46 must still be processed after pull #45 raises Octokit::NotFound on the pull_request lookup'
    )
  end

  def test_rescues_forbidden_on_pull_request_lookup
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/repos/foo/foo/issues/45',
      body: {
        number: 45, pull_request: { url: 'https://api.github.com/repos/foo/foo/pulls/45' },
        user: { id: 44, login: 'user' }, created_at: '2025-09-27 06:03:16 UTC'
      }
    )
    stub_github('https://api.github.com/repos/foo/foo/pulls/45', status: 403, body: { message: 'Resource not accessible by integration' })
    stub_github('https://api.github.com/user/44', body: { id: 44, login: 'user' })
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-opened', repository: 42, issue: 44, where: 'github')
      .with(_id: 2, what: 'pull-was-opened', repository: 42, issue: 46, where: 'github')
    load_it('find-missing-issues', fb)
    refute(
      fb.one?(what: 'issue-was-lost', where: 'github', issue: 45, repository: 42),
      '403 is transient — no issue-was-lost fact must be created on pull_request 403; next cycle will retry'
    )
  end
end
