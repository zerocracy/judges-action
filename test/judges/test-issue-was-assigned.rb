# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'fbe/octo'
require_relative '../test__helper'

class TestIssueWasAssigned < Jp::Test
  using SmartFactbase

  def test_reuses_repo_name_lookup_per_repo
    calls = Hash.new(0)
    octo = Object.new
    octo.define_singleton_method(:repo_name_by_id) do |repository|
      calls[repository] += 1
      'foo/foo'
    end
    octo.define_singleton_method(:repo_id_by_name) { |_repo| 42 }
    octo.define_singleton_method(:issue_events) { |_repo, _issue| [] }
    octo.define_singleton_method(:repository) { |_repo| { id: 42, full_name: 'foo/foo', archived: false } }
    octo.define_singleton_method(:off_quota?) { |*| false }
    octo.define_singleton_method(:print_trace!) { '' }
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, issue: 44, where: 'github')
      .with(_id: 2, what: 'issue-was-opened', repository: 42, issue: 45, where: 'github')
    Fbe.stub(:octo, octo) do
      load_it('issue-was-assigned', fb)
    end
    assert_equal({ 42 => 1 }, calls)
  end

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
    assert_equal(3, fb.all.size)
    assert_equal(2, fb.picks(what: 'issue-was-opened').size)
    assert_equal(0, fb.picks(what: 'issue-was-assigned').size)
    assert_equal(1, fb.picks(what: 'tombstone').size)
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

  def test_rescues_forbidden_on_issue_events_lookup
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, full_name: 'foo/foo' })
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/repos/foo/foo/issues/44/events?per_page=100',
      status: 403,
      body: { message: 'Resource not accessible by integration' }
    )
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, issue: 44, where: 'github')
    load_it('issue-was-assigned', fb)
    f = fb.query('(eq issue 44)').each.first
    refute_nil(f)
    assert_nil(
      f['stale'],
      '403 is transient — fact must NOT be marked stale; next cycle will retry the events lookup'
    )
  end

  def test_rescues_not_found_on_repo_name_lookup
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, name: 'foo', full_name: 'foo/foo' })
    stub_github('https://api.github.com/repositories/42', status: 404, body: { message: 'Not Found' })
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, issue: 44, where: 'github')
    load_it('issue-was-assigned', fb)
    assert_empty(
      fb.query("(eq what 'issue-was-assigned')").each.to_a,
      'A vanished repository must produce no facts and must not abort the judge'
    )
  end

  def test_records_a_reassignment_after_unassignment
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, name: 'foo', full_name: 'foo/foo' })
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/repos/foo/foo/issues/44/events?per_page=100',
      body: [
        {
          id: 560,
          event: 'assigned',
          assignee: { id: 421, login: 'user1' },
          assigner: { id: 422, login: 'user2' },
          created_at: '2025-10-03 09:00:00 UTC'
        }
      ]
    )
    stub_github('https://api.github.com/user/421', body: { id: 421, login: 'user1' })
    stub_github('https://api.github.com/user/422', body: { id: 422, login: 'user2' })
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, issue: 44, where: 'github')
    fb.with(
      _id: 2, what: 'issue-was-assigned', repository: 42, issue: 44, where: 'github', who: 421,
      assigner: 422, when: Time.parse('2025-10-01 19:05:00 UTC'), unassigned: Time.parse('2025-10-02 12:00:00 UTC'),
      details: 'foo/foo#44 was assigned to @user1 by @user2.'
    )
    load_it('issue-was-assigned', fb)
    assert_equal(
      2,
      fb.query('(and (eq what "issue-was-assigned") (eq issue 44) (eq who 421))').each.to_a.size,
      'the second assignment of the same person must get its own fact'
    )
  end

  def test_keeps_two_people_assigned_to_one_issue
    fb = assigned_after(44 => [{}, [5, 6]])
    assert_equal([5, 6], fb.query('(eq what "issue-was-assigned")').each.map(&:who).sort!, 'an assignee was lost')
  end

  def test_skips_done_issue
    fb = assigned_after(45 => [{ done: 1 }, [7]])
    assert_empty(fb.query('(eq what "issue-was-assigned")').each.to_a, 'a done issue got an assignment')
  end

  def test_skips_buried_issue
    fb = assigned_after(46 => [{ tombstone: 'yes' }, [7]])
    assert_empty(fb.query('(eq what "issue-was-assigned")').each.to_a, 'a buried issue got an assignment')
  end

  def test_assigns_only_live_issue_next_to_done_one
    fb = assigned_after(44 => [{}, [5, 6]], 45 => [{ done: 1 }, [7]])
    assert_equal([44, 44], fb.query('(eq what "issue-was-assigned")').each.map(&:issue), 'the done issue was assigned')
  end

  private

  def assigned_after(issues)
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, name: 'foo', full_name: 'foo/foo' })
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    [5, 6, 7, 9].each { |u| stub_github("https://api.github.com/user/#{u}", body: { id: u, login: "user#{u}" }) }
    fb = Factbase.new
    issues.each_with_index do |(n, (extra, whos)), i|
      stub_github(
        "https://api.github.com/repos/foo/foo/issues/#{n}/events?per_page=100",
        body: whos.map do |w|
          { id: w, event: 'assigned', assignee: { id: w }, assigner: { id: 9 }, created_at: "2025-10-0#{w} 19:05 UTC" }
        end
      )
      fb.with(_id: i + 1, what: 'issue-was-opened', repository: 42, issue: n, where: 'github', **extra)
    end
    load_it('issue-was-assigned', fb)
    fb
  end
end
