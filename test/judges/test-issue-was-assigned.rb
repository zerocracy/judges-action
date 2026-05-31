# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'fbe/octo'
require_relative '../test__helper'

class TestIssueWasAssigned < Jp::Test
  using SmartFactbase

  def test_reuses_repository_name_lookup_per_repository
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
    octo.define_singleton_method(:print_trace!) { nil }
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, issue: 44, where: 'github')
      .with(_id: 2, what: 'issue-was-opened', repository: 42, issue: 45, where: 'github')
    Fbe.stub(:octo, octo) do
      VCR.use_cassette('issue-was-assigned/reuses-repository-name-lookup-per-repository') do
        load_it('issue-was-assigned', fb)
      end
    end
    assert_equal({ 42 => 1 }, calls)
  end

  def test_not_found_issue_events
    rate_limit_up
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, issue: 44, where: 'github')
      .with(_id: 2, what: 'issue-was-opened', repository: 42, issue: 45, where: 'github')
    VCR.use_cassette('issue-was-assigned/not-found-issue-events') do
      load_it('issue-was-assigned', fb)
    end
    assert_equal(2, fb.all.size)
    assert_equal(2, fb.picks(what: 'issue-was-opened').size)
    assert_equal(0, fb.picks(what: 'issue-was-assigned').size)
  end

  def test_with_duplicate_assigned_event
    rate_limit_up
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, issue: 44, where: 'github')
    VCR.use_cassette('issue-was-assigned/with-duplicate-assigned-event') do
      load_it('issue-was-assigned', fb)
    end
    assert(
      fb.one?(
        what: 'issue-was-assigned', repository: 42, issue: 44, where: 'github', who: 421,
        assigner: 422, details: 'foo/foo#44 was assigned to @user1 by @user2.'
      )
    )
  end

  def test_rescues_forbidden_on_issue_events_lookup
    rate_limit_up
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, issue: 44, where: 'github')
    VCR.use_cassette('issue-was-assigned/rescues-forbidden-on-issue-events-lookup') do
      load_it('issue-was-assigned', fb)
    end
    f = fb.query('(eq issue 44)').each.first
    refute_nil(f)
    assert_nil(
      f['stale'],
      '403 is transient — fact must NOT be marked stale; next cycle will retry the events lookup'
    )
  end
end
