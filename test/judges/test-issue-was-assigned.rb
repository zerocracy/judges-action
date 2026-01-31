# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024 Yegor Bugayenko
# License:: MIT
class TestIssueWasAssigned < Jp::Test
  using SmartFactbase

  def test_not_found_issue_events
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, name: 'foo', full_name: 'foo/foo' })
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_github('https://api.github.com/repos/foo/foo/issues/44/events?per_page=100', body: [])
    stub_github(
      'https://api.github.com/repos/foo/foo/issues/45/events?per_page=100',
      status: 404,
      body: {
        message: 'Not Found',
        documentation_url: 'https://docs.github.com/rest/issues/events#list-issue-events',
        status: '404'
      }
    )
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, issue: 44, where: 'github')
      .with(_id: 2, what: 'issue-was-opened', repository: 42, issue: 45, where: 'github')
    load_it('issue-was-assigned', fb)
    assert_equal(2, fb.all.size)
    assert_equal(2, fb.picks(what: 'issue-was-opened').size)
    assert_equal(0, fb.picks(what: 'issue-was-assigned').size)
  end

  def test_with_duplicate_assigned_event
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, name: 'foo', full_name: 'foo/foo' })
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/repos/foo/foo/issues/44/events?per_page=100',
      body: [
        {
          id: 559,
          event: 'assigned',
          assignee: {
            id: 421,
            login: 'user1'
          },
          assigner: {
            id: 422,
            login: 'user2'
          },
          created_at: '2025-10-01 19:05:00 UTC'
        },
        {
          id: 559,
          event: 'assigned',
          assignee: {
            id: 421,
            login: 'user1'
          },
          assigner: {
            id: 422,
            login: 'user2'
          },
          created_at: '2025-10-02 21:05:00 UTC'
        }
      ]
    )
    stub_github('https://api.github.com/user/421', body: { id: 421, login: 'user1' })
    stub_github('https://api.github.com/user/422', body: { id: 422, login: 'user2' })
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, issue: 44, where: 'github')
    load_it('issue-was-assigned', fb)
    assert(
      fb.one?(
        what: 'issue-was-assigned', repository: 42, issue: 44, where: 'github', who: 421,
        assigner: 422, details: 'foo/foo#44 was assigned to @user1 by @user2.'
      )
    )
  end
end
