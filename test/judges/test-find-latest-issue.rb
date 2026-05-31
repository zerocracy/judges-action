# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../test__helper'

class TestFindLatestIssue < Jp::Test
  using SmartFactbase

  def test_find_latest_issue
    rate_limit_up
    fb = Factbase.new
    VCR.use_cassette('find-latest-issue/find-latest-issue') do
      load_it('find-latest-issue', fb)
    end
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
    rate_limit_up
    fb = Factbase.new
    VCR.use_cassette('find-latest-issue/find-latest-pull') do
      load_it('find-latest-issue', fb)
    end
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
    rate_limit_up
    fb = Factbase.new
    VCR.use_cassette('find-latest-issue/not-found-latest-issue') do
      load_it('find-latest-issue', fb)
    end
    assert_equal(0, fb.all.size)
  end

  def test_if_latest_issue_exist
    rate_limit_up
    fb = Factbase.new
    fb.with(
      _id: 1, what: 'issue-was-opened', issue: 547, repository: 42, where: 'github',
      who: 44, when: Time.parse('2025-09-14 20:03:16 UTC'),
      details: 'The issue foo/foo#547 has been opened by @user.'
    )
    VCR.use_cassette('find-latest-issue/if-latest-issue-exist') do
      load_it('find-latest-issue', fb)
    end
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
    rate_limit_up
    fb = Factbase.new
    fb.with(
      _id: 1, what: 'issue-was-opened', issue: 547, repository: 42, where: 'github',
      who: 44, when: Time.parse('2025-09-14 20:03:16 UTC'),
      details: 'The issue foo/foo#547 has been opened by @user.'
    ).with(
      _id: 2, what: 'iterate', where: 'github', repository: 42, latest_issue_was_found: 547
    )
    VCR.use_cassette('find-latest-issue/if-find-latest-issue-already-found') do
      load_it('find-latest-issue', fb)
    end
    assert_equal(2, fb.all.size)
    assert(fb.one?(what: 'iterate', latest_issue_was_found: 547, repository: 42, where: 'github'))
  end

  def test_rescues_not_found_on_pull_request_lookup
    rate_limit_up
    fb = Factbase.new
    VCR.use_cassette('find-latest-issue/rescues-not-found-on-pull-request-lookup') do
      load_it('find-latest-issue', fb)
    end
    assert(
      fb.one?(what: 'iterate', latest_issue_was_found: 548, repository: 42, where: 'github'),
      'cursor must advance to the issue number after a 404 on Fbe.octo.pull_request'
    )
  end

  def test_rescues_deprecated_on_pull_request_lookup
    rate_limit_up
    fb = Factbase.new
    VCR.use_cassette('find-latest-issue/rescues-deprecated-on-pull-request-lookup') do
      load_it('find-latest-issue', fb)
    end
    assert(
      fb.one?(what: 'iterate', latest_issue_was_found: 549, repository: 42, where: 'github'),
      'cursor must advance to the issue number after a 410 on Fbe.octo.pull_request'
    )
  end

  def test_rescues_forbidden_on_pull_request_lookup
    rate_limit_up
    fb = Factbase.new
    VCR.use_cassette('find-latest-issue/rescues-forbidden-on-pull-request-lookup') do
      load_it('find-latest-issue', fb)
    end
    refute(
      fb.one?(what: 'issue-was-lost', where: 'github', repository: 42, issue: 548),
      'forbidden error must not produce an issue-was-lost tombstone'
    )
  end
end
