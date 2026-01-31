# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'decoor'
require 'fbe/github_graph'
require 'factbase'
require 'judges/options'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2025 Yegor Bugayenko
# License:: MIT
class TestIssueWasClosed < Jp::Test
  using SmartFactbase

  def test_find_closed_issues
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/repos/foo/foo/issues/50',
      body: { number: 50, title: 'some title 50', state: 'open' }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/issues/51',
      status: 404,
      body: { message: 'Not Found', documentation_url: 'https://docs.github.com', status: '404' }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/issues/52',
      body: {
        number: 52, title: 'some title 52', state: 'closed',
        closed_at: Time.parse('2025-07-10 10:00:00 UTC'),
        closed_by: { login: 'user1', id: 222_111 }
      }
    )
    stub_github('https://api.github.com/repos/foo/foo/issues/52/timeline?per_page=100', body: [])
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, issue: 44, where: 'github')
      .with(_id: 2, what: 'issue-was-closed', repository: 42, issue: 44, where: 'github')
      .with(_id: 3, what: 'issue-was-opened', repository: 42, issue: 47, where: 'github')
      .with(_id: 4, what: 'issue-was-closed', repository: 42, issue: 47, where: 'github')
      .with(_id: 5, what: 'issue-was-opened', repository: 42, issue: 50, where: 'github')
      .with(_id: 6, what: 'issue-was-opened', repository: 42, issue: 51, where: 'github')
      .with(_id: 7, what: 'issue-was-opened', repository: 42, issue: 52, where: 'github')
      .with(_id: 8, what: 'issue-was-opened', repository: 42, issue: 44, where: 'gitlab')
      .with(_id: 9, what: 'issue-was-closed', repository: 42, issue: 44, where: 'gitlab')
    load_it('issue-was-closed', fb)
    assert_equal(6, fb.picks(what: 'issue-was-opened').size)
    assert_equal(4, fb.picks(what: 'issue-was-closed').size)
    assert(
      fb.one?(
        what: 'issue-was-closed',
        repository: 42,
        issue: 52,
        where: 'github',
        when: Time.parse('2025-07-10 10:00:00 UTC'),
        who: 222_111,
        details: 'Apparently, foo/foo#52 has been "issue-was-closed".'
      )
    )
  end

  def test_multiple_facts_with_identical_repository_and_issue
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/repos/foo/foo/issues/44',
      body: {
        number: 44, title: 'some title 44', state: 'closed',
        closed_at: Time.parse('2025-10-01 10:00:00 UTC'),
        closed_by: { login: 'user1', id: 222_111 }
      }
    )
    stub_github('https://api.github.com/repos/foo/foo/issues/44/timeline?per_page=100', body: [])
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, issue: 44, where: 'github')
      .with(_id: 2, what: 'bug-was-accepted', repository: 42, issue: 44, where: 'github')
    load_it('issue-was-closed', fb)
    assert(fb.one?(what: 'issue-was-closed', repository: 42, issue: 44, where: 'github'))
  end

  def test_find_closed_issues_with_labels
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
    stub_github(
      'https://api.github.com/repos/foo/foo/issues/52/timeline?per_page=100',
      body: [
        {
          id: 195,
          actor: { id: 421, login: 'user' },
          event: 'labeled',
          created_at: '2025-09-30 06:14:38 UTC',
          label: { name: 'bug', color: 'd73a4a' }
        }
      ]
    )
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, issue: 52, where: 'github')
    load_it('issue-was-closed', fb)
    assert_equal(1, fb.picks(what: 'issue-was-opened').size)
    assert_equal(1, fb.picks(what: 'label-was-attached').size)
    assert(
      fb.one?(what: 'label-was-attached', repository: 42, issue: 52, where: 'github', label: 'bug', who: 421)
    )
  end

  def test_find_closed_issues_without_labels
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
    stub_github(
      'https://api.github.com/repos/foo/foo/issues/52/timeline?per_page=100',
      body: []
    )
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, issue: 52, where: 'github')
    load_it('issue-was-closed', fb)
    assert_equal(1, fb.picks(what: 'issue-was-opened').size)
    assert_equal(0, fb.picks(what: 'label-was-attached').size)
  end

  def test_find_closed_issues_with_labels_and_exists_labels_fact
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
    stub_github(
      'https://api.github.com/repos/foo/foo/issues/52/timeline?per_page=100',
      body: [
        {
          id: 195,
          actor: { id: 421, login: 'user' },
          event: 'labeled',
          created_at: '2025-09-30 06:14:38 UTC',
          label: { name: 'bug', color: 'd73a4a' }
        }
      ]
    )
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, issue: 52, where: 'github')
      .with(_id: 2, what: 'label-was-attached', repository: 42, issue: 52, where: 'github', label: 'bug', who: 421)
    load_it('issue-was-closed', fb)
    assert_equal(1, fb.picks(what: 'issue-was-opened').size)
    assert_equal(1, fb.picks(what: 'label-was-attached').size)
    assert(
      fb.one?(what: 'label-was-attached', repository: 42, issue: 52, where: 'github', label: 'bug', who: 421)
    )
  end
end
