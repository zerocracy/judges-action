# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../test__helper'

class TestFindEarliestIssue < Jp::Test
  using SmartFactbase

  def test_find_earliest_issue
    rate_limit_up
    fb = Factbase.new
    VCR.use_cassette('find-earliest-issue/find-earliest-issue') do
      load_it('find-earliest-issue', fb)
    end
    assert_equal(2, fb.all.size)
    assert(
      fb.one?(
        what: 'issue-was-opened', issue: 3, repository: 42, where: 'github',
        who: 44, when: Time.parse('2025-09-27 05:03:16 UTC'),
        details: 'The issue foo/foo#3 is the earliest we found, opened by @user.'
      )
    )
    assert(fb.one?(what: 'iterate', earliest_issue_was_found: 3, repository: 42, where: 'github'))
  end

  def test_find_earliest_pull
    rate_limit_up
    fb = Factbase.new
    VCR.use_cassette('find-earliest-issue/find-earliest-pull') do
      load_it('find-earliest-issue', fb)
    end
    assert_equal(2, fb.all.size)
    assert(
      fb.one?(
        what: 'pull-was-opened', issue: 3, repository: 42, where: 'github',
        who: 44, branch: '2', when: Time.parse('2025-09-27 06:03:16 UTC'),
        details: 'The issue foo/foo#3 is the earliest we found, opened by @user.'
      )
    )
    assert(fb.one?(what: 'iterate', earliest_issue_was_found: 3, repository: 42, where: 'github'))
  end

  def test_not_found_earliest_issue
    rate_limit_up
    fb = Factbase.new
    VCR.use_cassette('find-earliest-issue/not-found-earliest-issue') do
      load_it('find-earliest-issue', fb)
    end
    assert_equal(0, fb.all.size)
  end

  def test_if_earliest_issue_exist
    rate_limit_up
    fb = Factbase.new
    fb.with(
      _id: 1, what: 'issue-was-opened', issue: 3, repository: 42, where: 'github',
      who: 44, when: Time.parse('2025-09-27 07:03:16 UTC'),
      details: 'The issue foo/foo#3 has been opened by @user.'
    )
    VCR.use_cassette('find-earliest-issue/if-earliest-issue-exist') do
      load_it('find-earliest-issue', fb)
    end
    assert_equal(2, fb.all.size)
    assert(
      fb.one?(
        _id: 1, what: 'issue-was-opened', issue: 3, repository: 42, where: 'github',
        who: 44, when: Time.parse('2025-09-27 07:03:16 UTC'),
        details: 'The issue foo/foo#3 has been opened by @user.'
      )
    )
    assert(fb.one?(what: 'iterate', earliest_issue_was_found: 3, repository: 42, where: 'github'))
  end

  def test_if_find_earliest_issue_already_found
    rate_limit_up
    fb = Factbase.new
    fb.with(
      _id: 1, what: 'issue-was-opened', issue: 3, repository: 42, where: 'github',
      who: 44, when: Time.parse('2025-09-27 07:03:16 UTC'),
      details: 'The issue foo/foo#3 has been opened by @user.'
    ).with(
      _id: 2, what: 'iterate', where: 'github', repository: 42, earliest_issue_was_found: 3
    )
    VCR.use_cassette('find-earliest-issue/if-find-earliest-issue-already-found') do
      load_it('find-earliest-issue', fb)
    end
    assert_equal(2, fb.all.size)
    assert(fb.one?(what: 'iterate', earliest_issue_was_found: 3, repository: 42, where: 'github'))
  end

  def test_rescues_not_found_on_pull_request_lookup
    rate_limit_up
    fb = Factbase.new
    VCR.use_cassette('find-earliest-issue/rescues-not-found-on-pull-request-lookup') do
      load_it('find-earliest-issue', fb)
    end
    assert(
      fb.one?(what: 'iterate', earliest_issue_was_found: 3, repository: 42, where: 'github'),
      'cursor must advance to the issue number after a 404 on Fbe.octo.pull_request'
    )
  end

  def test_rescues_not_found_on_list_issues
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, name: 'foo', full_name: 'foo/foo' })
    stub_github('https://api.github.com/repositories/42', body: { id: 42, name: 'foo', full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/repos/foo/foo/issues?direction=asc&page=1&per_page=1&sort=created&state=all',
      status: 404,
      body: { message: 'Not Found' }
    )
    fb = Factbase.new
    load_it('find-earliest-issue', fb)
    assert_equal(0, fb.all.size, 'no facts must be written when list_issues 404s')
  end

  def test_rescues_forbidden_on_list_issues
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, name: 'foo', full_name: 'foo/foo' })
    stub_github('https://api.github.com/repositories/42', body: { id: 42, name: 'foo', full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/repos/foo/foo/issues?direction=asc&page=1&per_page=1&sort=created&state=all',
      status: 403,
      body: { message: 'Resource not accessible by integration' }
    )
    fb = Factbase.new
    load_it('find-earliest-issue', fb)
    assert_equal(0, fb.all.size, 'no facts must be written when list_issues 403s — next cycle will retry')
  end

  def test_rescues_forbidden_on_pull_request_lookup
    rate_limit_up
    fb = Factbase.new
    VCR.use_cassette('find-earliest-issue/rescues-forbidden-on-pull-request-lookup') do
      load_it('find-earliest-issue', fb)
    end
    refute(
      fb.one?(what: 'issue-was-lost', where: 'github', repository: 42, issue: 3),
      'forbidden error must not produce an issue-was-lost tombstone'
    )
  end

  def test_rescues_deprecated_on_pull_request_lookup
    rate_limit_up
    fb = Factbase.new
    VCR.use_cassette('find-earliest-issue/rescues-deprecated-on-pull-request-lookup') do
      load_it('find-earliest-issue', fb)
    end
    assert(
      fb.one?(what: 'iterate', earliest_issue_was_found: 4, repository: 42, where: 'github'),
      'cursor must advance to the issue number after a 410 on Fbe.octo.pull_request'
    )
  end
end
