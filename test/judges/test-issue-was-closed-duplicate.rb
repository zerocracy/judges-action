# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'fbe/if_absent'
require 'judges/options'
require_relative '../test__helper'

class TestIssueWasClosedDuplicate < Jp::Test
  using SmartFactbase

  def test_asks_for_no_timeline_of_an_already_closed_issue
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/repos/foo/foo/issues/52',
      body: {
        number: 52, title: 'some title 52', state: 'closed',
        closed_at: Time.parse('2025-07-10 10:00:00 UTC'),
        closed_by: { login: 'user1', id: 222_111 }
      }
    )
    timeline = stub_github('https://api.github.com/repos/foo/foo/issues/52/timeline?per_page=100', body: [])
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, issue: 52, where: 'github')
    Fbe.stub(:if_absent, ->(*, **, &_blk) {}) do
      load_it('issue-was-closed', fb)
    end
    assert_not_requested(timeline, message: 'an issue already closed cannot cost a timeline call')
  end
end
