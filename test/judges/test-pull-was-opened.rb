# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../fake_github'
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
    assert(
      fb.one?(what: 'pull-was-reviewed', repository: 42, issue: 44, where: 'github'),
      'seed fact must remain in factbase'
    )
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
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/44',
      status: 403,
      body: { message: 'Resource not accessible by integration' }
    )
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

  def test_rescues_not_found_on_repo_name_lookup
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repositories/42', status: 404, body: { message: 'Not Found' })
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-reviewed', repository: 42, issue: 44, where: 'github')
    load_it('pull-was-opened', fb)
    assert_empty(
      fb.query("(eq what 'pull-was-opened')").each.to_a,
      'A vanished repository must produce no facts and must not abort the judge'
    )
  end

  def test_copies_branch_from_pull_request
    seed = Random.new_seed
    branch = "фича-#{Random.new(seed).rand(1_000_000)}/Ω"
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-reviewed', repository: 42, issue: 44, where: 'github')
    Jp::FakeGithub.new(
      'GET /rate_limit' => { resources: { search: { remaining: 30, limit: 30 } }, rate: { remaining: 1000 } },
      'GET /repositories/42' => { id: 42, full_name: 'foo/foo' },
      'GET /repos/foo/foo/issues/44' => {
        number: 44, user: { id: 421, login: 'user' }, created_at: '2025-09-30T15:35:30Z'
      },
      'GET /repos/foo/foo/pulls/44' => { number: 44, head: { ref: branch } },
      'GET /user/421' => { id: 421, login: 'user' }
    ).run do
      load_it('pull-was-opened', fb)
    end
    assert_equal(
      [branch], fb.pick(what: 'pull-was-opened', issue: 44)['branch'],
      "the branch of the opened pull is not the head ref of the pull request, seed #{seed}"
    )
  end

  def test_marks_fact_stale_when_pull_has_no_head_ref
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-reviewed', repository: 42, issue: 44, where: 'github')
    Jp::FakeGithub.new(
      'GET /rate_limit' => { resources: { search: { remaining: 30, limit: 30 } }, rate: { remaining: 1000 } },
      'GET /repositories/42' => { id: 42, full_name: 'foo/foo' },
      'GET /repos/foo/foo/issues/44' => {
        number: 44, user: { id: 421, login: 'user' }, created_at: '2025-09-30T15:35:30Z'
      },
      'GET /repos/foo/foo/pulls/44' => { number: 44, head: {} },
      'GET /user/421' => { id: 421, login: 'user' }
    ).run do
      load_it('pull-was-opened', fb)
    end
    assert_equal(
      ['branch'], fb.pick(what: 'pull-was-opened', issue: 44)['stale'],
      'the opened pull without a head ref is not marked stale by branch, so it would be retried forever'
    )
  end
end
