# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
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
end
