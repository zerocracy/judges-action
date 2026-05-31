# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../test__helper'

class TestFindMissingIssues < Jp::Test
  using SmartFactbase

  def test_find_missing_issues_if_issue_not_found
    rate_limit_up
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, issue: 44, where: 'github')
      .with(_id: 2, what: 'issue-was-opened', repository: 42, issue: 46, where: 'github')
    VCR.use_cassette('find-missing-issues/find-missing-issues-if-issue-not-found') do
      load_it('find-missing-issues', fb)
    end
    assert(fb.one?(what: 'issue-was-lost', where: 'github', issue: 45, repository: 42, stale: 'issue'))
    assert(fb.one?(what: 'tombstone', where: 'github', issues: '45', repository: 42))
  end

  def test_rescues_forbidden_on_issue_lookup
    rate_limit_up
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, issue: 44, where: 'github')
      .with(_id: 2, what: 'issue-was-opened', repository: 42, issue: 46, where: 'github')
    VCR.use_cassette('find-missing-issues/rescues-forbidden-on-issue-lookup') do
      load_it('find-missing-issues', fb)
    end
    refute(
      fb.one?(what: 'issue-was-lost', where: 'github', issue: 45, repository: 42),
      '403 is transient — no issue-was-lost fact must be created; next cycle will retry the issue lookup'
    )
  end

  def test_continues_scan_after_pull_request_not_found
    rate_limit_up
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-opened', repository: 42, issue: 44, where: 'github')
      .with(_id: 2, what: 'pull-was-opened', repository: 42, issue: 47, where: 'github')
    VCR.use_cassette('find-missing-issues/continues-scan-after-pull-request-not-found') do
      load_it('find-missing-issues', fb)
    end
    assert(
      fb.one?(what: 'pull-was-opened', issue: 46, repository: 42, where: 'github', branch: 'feature-x'),
      'pull #46 must still be processed after pull #45 raises Octokit::NotFound on the pull_request lookup'
    )
  end

  def test_rescues_forbidden_on_pull_request_lookup
    rate_limit_up
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-opened', repository: 42, issue: 44, where: 'github')
      .with(_id: 2, what: 'pull-was-opened', repository: 42, issue: 46, where: 'github')
    VCR.use_cassette('find-missing-issues/rescues-forbidden-on-pull-request-lookup') do
      load_it('find-missing-issues', fb)
    end
    refute(
      fb.one?(what: 'issue-was-lost', where: 'github', issue: 45, repository: 42),
      '403 is transient — no issue-was-lost fact must be created on pull_request 403; next cycle will retry'
    )
  end
end
