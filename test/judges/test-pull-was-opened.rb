# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../test__helper'

class TestPullWasOpened < Jp::Test
  using SmartFactbase

  def test_rescues_forbidden_on_issue_lookup
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, full_name: 'foo/foo' })
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/repos/foo/foo/issues/44',
      status: 403,
      body: { message: 'Resource not accessible by integration' }
    )
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-reviewed', repository: 42, issue: 44, where: 'github')
    load_it('pull-was-opened', fb)
    assert(fb.one?(what: 'pull-was-reviewed', repository: 42, issue: 44, where: 'github'), 'seed fact must remain in factbase')
    refute(
      fb.one?(what: 'pull-was-reviewed', repository: 42, issue: 44, where: 'github', stale: 'issue'),
      '403 is transient — fact must NOT be marked stale; next cycle will retry the issue lookup'
    )
  end

  def test_rescues_not_found_on_pull_request_lookup
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, full_name: 'foo/foo' })
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/repos/foo/foo/issues/44',
      body: {
        number: 44, state: 'open', user: { id: 421, login: 'user' },
        created_at: Time.parse('2025-09-30 15:35:30 UTC')
      }
    )
    stub_github('https://api.github.com/repos/foo/foo/pulls/44', status: 404, body: { message: 'Not Found' })
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-reviewed', repository: 42, issue: 44, where: 'github')
    load_it('pull-was-opened', fb)
    refute(
      fb.one?(what: 'pull-was-opened', repository: 42, issue: 44, where: 'github'),
      'partial pull-was-opened fact must be rolled back when the pull_request lookup 404s'
    )
    assert(
      fb.one?(what: 'pull-was-reviewed', repository: 42, issue: 44, where: 'github', stale: 'issue'),
      'a 404 on the follow-up pull_request lookup must mark the seed fact as stale'
    )
  end

  def test_rescues_forbidden_on_pull_request_lookup
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, full_name: 'foo/foo' })
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/repos/foo/foo/issues/44',
      body: {
        number: 44, state: 'open', user: { id: 421, login: 'user' },
        created_at: Time.parse('2025-09-30 15:35:30 UTC')
      }
    )
    stub_github('https://api.github.com/repos/foo/foo/pulls/44', status: 403, body: { message: 'Resource not accessible by integration' })
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-reviewed', repository: 42, issue: 44, where: 'github')
    load_it('pull-was-opened', fb)
    refute(
      fb.one?(what: 'pull-was-opened', repository: 42, issue: 44, where: 'github'),
      'partial pull-was-opened fact must be rolled back when the pull_request lookup 403s'
    )
    refute(
      fb.one?(what: 'issue-was-lost', repository: 42, issue: 44, where: 'github'),
      '403 is transient — the issue must NOT be marked lost; next cycle will retry'
    )
  end
end
