# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024 Yegor Bugayenko
# License:: MIT
class TestAssigneeWasAttached < Jp::Test
  using SmartFactbase

  def test_find_assigned_events_for_issues
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/repos/foo/foo/issues/45/events?per_page=100',
      body: [
        {
          id: 726, actor: { login: 'user', id: 411, type: 'User' },
          event: 'labeled', created_at: Time.parse('2025-05-30 21:41:00 UTC'),
          label: { name: 'bug', color: 'd73a4a' }
        },
        {
          id: 608, actor: { login: 'user2', id: 422, type: 'User' },
          event: 'assigned', created_at: Time.parse('2025-05-30 20:59:08 UTC'),
          assignee: { login: 'user2', id: 422, type: 'User' },
          assigner: { login: 'user', id: 411, type: 'User' }
        },
        {
          id: 539, actor: { login: 'user2', id: 422, type: 'User' },
          event: 'subscribed', created_at: Time.parse('2025-05-30 15:41:10 UTC')
        },
        {
          id: 408, actor: { login: 'user3', id: 423, type: 'User' },
          event: 'assigned', created_at: Time.parse('2025-05-29 17:59:08 UTC'),
          assignee: { login: 'user3', id: 423, type: 'User' },
          assigner: { login: 'user4', id: 414, type: 'User' }
        },
        {
          id: 376, actor: { login: 'user2', id: 422, type: 'User' },
          event: 'referenced', commit_id: '4621af032170f43d',
          commit_url: 'https://api.github.com/repos/foo/foo/commits/4621af032170f43d',
          created_at: Time.parse('2025-05-28 19:57:50 UTC')
        }
      ]
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/issues/47/events?per_page=100',
      body: [
        {
          id: 1376, actor: { login: 'user80', id: 80, type: 'User' },
          event: 'assigned', created_at: Time.parse('2025-05-30T15:00:00Z'),
          assignee: { login: 'user80', id: 80, type: 'User' },
          assigner: { login: 'user70', id: 70, type: 'User' }
        },
        {
          id: 1208, actor: { login: 'user2', id: 422, type: 'User' },
          event: 'assigned', created_at: Time.parse('2025-05-29 17:59:08 UTC'),
          assignee: { login: 'user2', id: 422, type: 'User' },
          assigner: { login: 'user', id: 411, type: 'User' }
        },
        {
          id: 1110, actor: { login: 'user2', id: 422, type: 'User' },
          event: 'referenced', commit_id: '4621af032170f43d',
          commit_url: 'https://api.github.com/repos/foo/foo/commits/4621af032170f43d',
          created_at: Time.parse('2025-05-28 19:57:50 UTC')
        }
      ]
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/issues/49/events?per_page=100',
      body: [
        {
          id: 2111, actor: { login: 'user2', id: 422, type: 'User' },
          event: 'referenced', commit_id: '4621af032170f43d',
          commit_url: 'https://api.github.com/repos/foo/foo/commits/4621af032170f43d',
          created_at: Time.parse('2025-05-28 19:57:50 UTC')
        }
      ]
    )
    stub_github('https://api.github.com/repos/foo/foo/issues/51/events?per_page=100', body: [])
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, issue: 44, where: 'github')
      .with(_id: 2, what: 'issue-was-assigned', repository: 42, issue: 44, where: 'github')
      .with(_id: 3, what: 'issue-was-opened', repository: 42, issue: 45, where: 'github')
      .with(_id: 4, what: 'issue-was-closed', repository: 42, issue: 45, where: 'github')
      .with(_id: 5, what: 'issue-was-opened', repository: 42, issue: 45, where: 'gitlab')
      .with(_id: 6, what: 'issue-was-opened', repository: 42, issue: 47, where: 'github')
      .with(_id: 7, what: 'issue-was-opened', repository: 42, issue: 49, where: 'github')
      .with(_id: 8, what: 'issue-was-opened', repository: 42, issue: 51, where: 'github')
    load_it('assignee-was-attached', fb)
    assert_equal(10, fb.all.size)
    assert_equal(6, fb.picks(what: 'issue-was-opened').size)
    assert_equal(1, fb.picks(what: 'issue-was-closed').size)
    assert_equal(3, fb.picks(what: 'issue-was-assigned').size)
    assert(fb.one?(what: 'issue-was-assigned', repository: 42, issue: 45, where: 'github',
                   when: Time.parse('2025-05-30 20:59:08 UTC'), who: 422, assigner: 411))
    assert(fb.one?(what: 'issue-was-assigned', repository: 42, issue: 47, where: 'github',
                   when: Time.parse('2025-05-30T15:00:00Z'), who: 80, assigner: 70))
    assert(fb.none?(what: 'issue-was-assigned', repository: 42, issue: 49, where: 'github'))
    assert(fb.none?(what: 'issue-was-assigned', repository: 42, issue: 51, where: 'github'))
  end
end
