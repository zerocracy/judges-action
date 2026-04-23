# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../test__helper'

class TestPullWasOpened < Jp::Test
  using SmartFactbase

  def test_rescues_forbidden_on_issue_lookup
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, full_name: 'foo/foo' })
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/repos/foo/foo/issues/44',
      status: 403,
      body: { message: 'Resource not accessible by integration' }
    )
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-reviewed', repository: 42, issue: 44, where: 'github')
    load_it('pull-was-opened', fb)
    assert(
      fb.one?(what: 'pull-was-reviewed', repository: 42, issue: 44, where: 'github', stale: 'issue'),
      'Jp.issue_was_lost should mark the fact stale=issue when issue lookup returns 403'
    )
  end
end
