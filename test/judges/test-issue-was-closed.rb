# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'decoor'
require 'factbase'
require 'fbe/github_graph'
require 'judges/options'
require_relative '../test__helper'

class TestIssueWasClosed < Jp::Test
  using SmartFactbase

  def test_find_closed_issues
    rate_limit_up
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
    VCR.use_cassette('issue-was-closed/find-closed-issues') do
      load_it('issue-was-closed', fb)
    end
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
    rate_limit_up
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, issue: 44, where: 'github')
      .with(_id: 2, what: 'bug-was-accepted', repository: 42, issue: 44, where: 'github')
    VCR.use_cassette('issue-was-closed/multiple-facts-with-identical-repository-and-issue') do
      load_it('issue-was-closed', fb)
    end
    assert(fb.one?(what: 'issue-was-closed', repository: 42, issue: 44, where: 'github'))
  end

  def test_find_closed_issues_with_labels
    rate_limit_up
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, issue: 52, where: 'github')
    VCR.use_cassette('issue-was-closed/find-closed-issues-with-labels') do
      load_it('issue-was-closed', fb)
    end
    assert_equal(1, fb.picks(what: 'issue-was-opened').size)
    assert_equal(1, fb.picks(what: 'label-was-attached').size)
    assert(fb.one?(what: 'label-was-attached', repository: 42, issue: 52, where: 'github', label: 'bug', who: 421))
  end

  def test_find_closed_issues_without_labels
    rate_limit_up
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, issue: 52, where: 'github')
    VCR.use_cassette('issue-was-closed/find-closed-issues-without-labels') do
      load_it('issue-was-closed', fb)
    end
    assert_equal(1, fb.picks(what: 'issue-was-opened').size)
    assert_equal(0, fb.picks(what: 'label-was-attached').size)
  end

  def test_find_closed_issues_with_labels_and_exists_labels_fact
    rate_limit_up
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, issue: 52, where: 'github')
      .with(_id: 2, what: 'label-was-attached', repository: 42, issue: 52, where: 'github', label: 'bug', who: 421)
    VCR.use_cassette('issue-was-closed/find-closed-issues-with-labels-and-exists-labels-fact') do
      load_it('issue-was-closed', fb)
    end
    assert_equal(1, fb.picks(what: 'issue-was-opened').size)
    assert_equal(1, fb.picks(what: 'label-was-attached').size)
    assert(fb.one?(what: 'label-was-attached', repository: 42, issue: 52, where: 'github', label: 'bug', who: 421))
  end

  def test_marks_label_stale_on_who_when_timeline_actor_is_nil
    rate_limit_up
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, issue: 52, where: 'github')
    VCR.use_cassette('issue-was-closed/marks-label-stale-on-who-when-timeline-actor-is-nil') do
      load_it('issue-was-closed', fb)
    end
    f = fb.query("(and (eq what 'label-was-attached') (eq label 'bug'))").each.first
    refute_nil(f)
    assert_nil(f['who'], 'who must not be set to nil for a deleted timeline actor')
    assert_equal(['who'], f['stale'], 'a deleted timeline actor must mark the fact stale on who')
    assert_match(/an unknown actor/, f['details'].first)
  end

  def test_rescues_forbidden_on_issue_lookup
    rate_limit_up
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, issue: 44, where: 'github')
    VCR.use_cassette('issue-was-closed/rescues-forbidden-on-issue-lookup') do
      load_it('issue-was-closed', fb)
    end
    f = fb.query('(eq issue 44)').each.first
    refute_nil(f)
    assert_nil(f['stale'], '403 is transient — fact must NOT be marked stale; next cycle will retry the lookup')
  end

  def test_rescues_forbidden_on_timeline_lookup
    rate_limit_up
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, issue: 44, where: 'github')
    VCR.use_cassette('issue-was-closed/rescues-forbidden-on-timeline-lookup') do
      load_it('issue-was-closed', fb)
    end
    assert(
      fb.one?(what: 'issue-was-closed', repository: 42, issue: 44, where: 'github', who: 222_111),
      'issue-was-closed fact should still be created — only timeline processing is skipped on 403'
    )
    assert_empty(
      fb.query("(eq what 'label-was-attached')").each.to_a,
      'no label-was-attached facts since timeline was inaccessible'
    )
  end
end
