# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../test__helper'

class TestIssueOpenedDetails < Jp::Test
  using SmartFactbase

  def test_describes_the_issue_and_its_author
    assert_match(%r{foo/foo#44\b.*@alice\b}, recover({ id: 421, login: 'alice' }).details)
  end

  def test_describes_an_issue_with_a_deleted_author
    assert_match(%r{foo/foo#44\b.*deleted.*account}, recover(nil).details)
  end

  private

  def recover(user)
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, full_name: 'foo/foo' })
    stub_github('https://api.github.com/user/421', body: { id: 421, login: 'alice' })
    stub_github(
      'https://api.github.com/repos/foo/foo/issues/44',
      body: { number: 44, created_at: '2025-01-01T12:00:00Z', user: }
    )
    fb = Factbase.new
    fb.with(what: 'issue-was-closed', repository: 42, issue: 44, where: 'github')
    load_it('issue-was-opened', fb)
    fb.pick(what: 'issue-was-opened')
  end
end
