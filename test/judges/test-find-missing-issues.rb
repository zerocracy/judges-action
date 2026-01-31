# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../test__helper'

# Test.
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
end
