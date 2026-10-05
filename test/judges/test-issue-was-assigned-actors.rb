# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'fbe/octo'
require_relative '../test__helper'

class TestIssueWasAssignedActors < Jp::Test
  using SmartFactbase

  def test_survives_an_event_without_an_assignee
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, name: 'foo', full_name: 'foo/foo' })
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/repos/foo/foo/issues/44/events?per_page=100',
      body: [{ event: 'assigned', created_at: Time.parse('2025-05-01 10:00:00 UTC') }]
    )
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, issue: 44, where: 'github')
    load_it('issue-was-assigned', fb)
    assert_empty(
      fb.query("(eq what 'issue-was-assigned')").each.to_a,
      'an event with no assignee cannot become a fact'
    )
  end

  def test_marks_a_missing_assigner_as_stale
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, name: 'foo', full_name: 'foo/foo' })
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/repos/foo/foo/issues/44/events?per_page=100',
      body: [
        {
          event: 'assigned', created_at: Time.parse('2025-05-01 10:00:00 UTC'),
          assignee: { login: 'user1', id: 222_111 }
        }
      ]
    )
    stub_github('https://api.github.com/user/222111', body: { login: 'user1', id: 222_111 })
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, issue: 44, where: 'github')
    load_it('issue-was-assigned', fb)
    f = fb.query("(eq what 'issue-was-assigned')").each.first
    refute_nil(f, 'an event with an assignee must still become a fact')
    assert_equal(['assigner'], f['stale'], 'an absent assigner must be recorded as stale')
  end
end
