# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../fake_github'
require_relative '../test__helper'

class TestFixMissingWho < Jp::Test
  using SmartFactbase

  def test_rescues_forbidden_on_issue_lookup
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-opened', repository: 42, issue: 44, where: 'github')
    Jp::FakeGithub.new(
      'GET /rate_limit' => { resources: { search: { remaining: 30, limit: 30 } }, rate: { remaining: 1000 } },
      'GET /repos/foo/foo' => { id: 42, full_name: 'foo/foo' },
      'GET /repositories/42' => { id: 42, full_name: 'foo/foo' },
      'GET /repos/foo/foo/issues/44' => [403, { message: 'Resource not accessible by integration' }]
    ).run do
      load_it('fix-missing-who', fb)
    end
    assert_nil(
      fb.pick(issue: 44)['stale'],
      'the fact is stale after a transient 403, while the next cycle must retry the issue lookup'
    )
  end

  def test_rescues_deprecated_on_issue_lookup
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, issue: 55, where: 'github')
    Jp::FakeGithub.new(
      'GET /rate_limit' => { resources: { search: { remaining: 30, limit: 30 } }, rate: { remaining: 1000 } },
      'GET /repos/foo/foo' => { id: 42, full_name: 'foo/foo' },
      'GET /repositories/42' => { id: 42, full_name: 'foo/foo' },
      'GET /repos/foo/foo/issues/55' => [410, { message: 'Issues are disabled for this repo' }]
    ).run do
      load_it('fix-missing-who', fb)
    end
    assert_equal(
      'issue', fb.pick(issue: 55)['stale'].first,
      'the issue is not stale after a permanent 410, while the judge must give up on it'
    )
  end

  def test_reads_merged_by_from_pull_endpoint
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-merged', repository: 42, issue: 66, where: 'github')
    Jp::FakeGithub.new(
      'GET /rate_limit' => { resources: { search: { remaining: 30, limit: 30 } }, rate: { remaining: 1000 } },
      'GET /repos/foo/foo' => { id: 42, full_name: 'foo/foo' },
      'GET /repositories/42' => { id: 42, full_name: 'foo/foo' },
      'GET /repos/foo/foo/pulls/66' => { number: 66, merged_by: { id: 7, login: 'merger' } }
    ).run do
      load_it('fix-missing-who', fb)
    end
    assert_equal(
      7, fb.pick(issue: 66).who,
      'the author is not the merged_by user of the pull request, while the judge must copy it from there'
    )
  end

  def test_rescues_not_found_on_repo_name_lookup
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-opened', repository: 42, issue: 44, where: 'github')
    Jp::FakeGithub.new(
      'GET /rate_limit' => { resources: { search: { remaining: 30, limit: 30 } }, rate: { remaining: 1000 } },
      'GET /repositories/42' => [404, { message: 'Not Found' }]
    ).run do
      load_it('fix-missing-who', fb)
    end
    assert(
      fb.one?(what: 'pull-was-opened', repository: 42, stale: 'repository'),
      'the fact of a vanished repository is not stale, while the judge must mark it instead of aborting'
    )
  end

  def test_continues_after_timeout_on_repo_name_lookup
    WebMock.disable_net_connect!
    rate_limit_up
    stub_request(:get, 'https://api.github.com/repositories/42').to_timeout
    stub_github(
      'https://api.github.com/repositories/43',
      body: { id: 43, full_name: 'bar/bar' }
    )
    stub_github(
      'https://api.github.com/repos/bar/bar/issues/45',
      body: { number: 45, user: { id: 7, login: 'reporter' } }
    )
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, issue: 44, where: 'github')
    fb.with(_id: 2, what: 'issue-was-opened', repository: 43, issue: 45, where: 'github')
    options = Judges::Options.new({ 'repositories' => 'foo/foo,bar/bar' })
    load_it('fix-missing-who', fb, options)
    assert_nil(fb.pick(issue: 44).who, 'the timed-out fact should remain eligible for a later retry')
    assert_equal(7, fb.pick(issue: 45).who, 'a repository timeout should not stop later facts from being repaired')
  end

  def test_continues_after_server_error_on_issue_lookup
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_github('https://api.github.com/repositories/43', body: { id: 43, full_name: 'bar/bar' })
    stub_github(
      'https://api.github.com/repos/foo/foo/issues/44',
      status: 500,
      body: { message: 'Server Error' }
    )
    stub_github(
      'https://api.github.com/repos/bar/bar/issues/45',
      body: { number: 45, user: { id: 7, login: 'reporter' } }
    )
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, issue: 44, where: 'github')
    fb.with(_id: 2, what: 'issue-was-opened', repository: 43, issue: 45, where: 'github')
    options = Judges::Options.new({ 'repositories' => 'foo/foo,bar/bar' })
    load_it('fix-missing-who', fb, options)
    assert_nil(fb.pick(issue: 44).who, 'the failed fact should remain eligible for a later retry')
    assert_equal(7, fb.pick(issue: 45).who, 'a server error should not stop later facts from being repaired')
  end
end
