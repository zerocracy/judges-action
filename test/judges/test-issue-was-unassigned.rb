# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024 Yegor Bugayenko
# License:: MIT
class TestIssueWasUnassigned < Jp::Test
  using SmartFactbase

  def test_not_found_issue_events
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, name: 'foo', full_name: 'foo/foo' })
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/repos/foo/foo/issues/44/events?per_page=100',
      status: 404,
      body: {
        message: 'Not Found',
        documentation_url: 'https://docs.github.com/rest/issues/events#list-issue-events',
        status: '404'
      }
    )
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-assigned', repository: 42, issue: 44, where: 'github', who: 421)
    load_it('issue-was-unassigned', fb)
    assert_equal(1, fb.picks(what: 'issue-was-assigned').size)
    assert_nil(fb.pick(what: 'issue-was-assigned')['unassigned'])
  end

  def test_without_unassignes_events
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, name: 'foo', full_name: 'foo/foo' })
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/repos/foo/foo/issues/44/events?per_page=100',
      body: [
        {
          id: 300, event: 'assigned',
          assignee: { id: 421, login: 'user1' },
          assigner: { id: 422, login: 'user2' },
          created_at: '2025-10-01 19:05:00 UTC'
        },
        {
          id: 301, event: 'mentioned',
          actor: { id: 421, login: 'user1' },
          created_at: '2025-10-02 21:05:00 UTC'
        }
      ]
    )
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-assigned', repository: 42, issue: 44, where: 'github', who: 421)
    load_it('issue-was-unassigned', fb)
    assert_equal(1, fb.picks(what: 'issue-was-assigned').size)
    assert_nil(fb.pick(what: 'issue-was-assigned')['unassigned'])
  end

  def test_with_unassignes_events
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, name: 'foo', full_name: 'foo/foo' })
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/repos/foo/foo/issues/44/events?per_page=100',
      body: [
        {
          id: 300, event: 'assigned',
          assignee: { id: 421, login: 'user1' },
          assigner: { id: 422, login: 'user2' },
          created_at: '2025-10-01 19:05:00 UTC'
        },
        {
          id: 301, event: 'unassigned',
          assignee: { id: 421, login: 'user1' },
          assigner: { id: 422, login: 'user2' },
          created_at: '2025-10-02 21:05:00 UTC'
        },
        {
          id: 302, event: 'assigned',
          assignee: { id: 421, login: 'user1' },
          assigner: { id: 422, login: 'user2' },
          created_at: '2025-10-03 17:45:00 UTC'
        },
        {
          id: 303, event: 'unassigned',
          assignee: { id: 423, login: 'user3' },
          assigner: { id: 422, login: 'user2' },
          created_at: '2025-10-04 21:55:00 UTC'
        },
        {
          id: 304, event: 'unassigned',
          assignee: { id: 421, login: 'user1' },
          assigner: { id: 422, login: 'user2' },
          created_at: '2025-10-05 23:55:00 UTC'
        },
        {
          id: 305, event: 'assigned',
          assignee: { id: 421, login: 'user1' },
          assigner: { id: 422, login: 'user2' },
          created_at: '2025-10-06 19:05:00 UTC'
        },
        {
          id: 306, event: 'unassigned',
          assignee: { id: 421, login: 'user1' },
          assigner: { id: 422, login: 'user2' },
          created_at: '2025-10-07 22:05:00 UTC'
        }
      ]
    )
    stub_github('https://api.github.com/user/421', body: { id: 421, login: 'user1' })
    fb = Factbase.new
    fb.with(
      _id: 1, what: 'issue-was-assigned', repository: 42, issue: 44, where: 'github',
      who: 421, when: Time.parse('2025-10-03 17:45:00 UTC')
    )
    load_it('issue-was-unassigned', fb)
    assert_equal(1, fb.picks(what: 'issue-was-assigned').size)
    assert_equal(Time.parse('2025-10-05 23:55:00 UTC'), fb.pick(what: 'issue-was-assigned').unassigned)
  end
end
