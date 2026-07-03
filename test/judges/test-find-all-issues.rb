# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'json'
require 'judges/options'
require 'loog'
require_relative '../test__helper'

class TestFindAllIssues < Jp::Test
  def test_find_all_issues_without_issues_in_fb
    rate_limit_up
    fb = Factbase.new
    VCR.use_cassette('find-all-issues/find-all-issues-without-issues-in-fb') do
      load_it('find-all-issues', fb)
    end
    fs = fb.query('(always)').each.to_a
    assert_equal(0, fs.count)
    assert_empty(fb.query("(eq what 'issue-was-opened')").each.to_a)
  end

  def test_restores_one_missing_fact
    rate_limit_up
    fb = Factbase.new
    fb.insert.then do |f|
      f.issue = 45
      f.repository = 991
      f.what = 'issue-was-opened'
      f.where = 'github'
    end
    VCR.use_cassette('find-all-issues/restores-one-missing-fact') do
      load_it('find-all-issues', fb)
    end
    assert_equal(3, fb.size)
    refute_empty(fb.query('(eq issue 46)').each.to_a)
  end

  def test_restarts_after_zero
    fb = Factbase.new
    fb.insert.then do |f|
      f._id = 10
      f.issue = 880
      f.repository = 1579
      f.what = 'issue-was-opened'
      f.where = 'github'
    end
    fb.insert.then do |f|
      f._id = 11
      f.what = 'iterate'
      f.min_issue_was_found = 0
      f.where = 'github'
      f.repository = 1579
    end
    VCR.use_cassette('find-all-issues/restarts-after-zero') do
      load_it('find-all-issues', fb, Judges::Options.new({ 'testing' => true, 'repositories' => 'yegor256/factbase' }))
    end
    assert_equal(3, fb.size)
  end

  def test_find_all_issues_with_not_found_min_issue_in_github
    fb = Factbase.new
    fb.insert.then do |f|
      f.details = 'The issue foo/foo#87 has been opened by @bar.'
      f.event_id = 1_598_476_635
      f.event_type = 'IssuesEvent'
      f.is_human = 1
      f.issue = 87
      f.repository = 695
      f.what = 'issue-was-opened'
      f.when = Time.parse('2024-09-10T15:00:00Z')
      f.where = 'github'
      f.who = 257_964
    end
    VCR.use_cassette('find-all-issues/find-all-issues-with-not-found-min-issue-in-github') do
      load_it('find-all-issues', fb)
    end
    fs = fb.query('(always)').each.to_a
    assert_equal(1, fs.count)
    refute_empty(fb.query("(eq what 'issue-was-opened')").each.to_a)
  end

  def test_find_all_issues
    rate_limit_up
    fb = Factbase.new
    fb.insert.then do |f|
      f.details = 'The issue foo/foo#87 has been opened by @bar.'
      f.event_id = 1_598_476_635
      f.event_type = 'IssuesEvent'
      f.is_human = 1
      f.issue = 87
      f.repository = 695
      f.what = 'issue-was-opened'
      f.when = Time.parse('2024-09-10T15:00:00Z')
      f.where = 'github'
      f.who = 257_964
    end
    fb.insert.then do |f|
      f.issue = 85
      f.repository = 700
      f.what = 'issue-was-opened'
      f.when = Time.parse('2024-09-09T15:00:00Z')
      f.where = 'github'
      f.who = 257_961
    end
    fb.insert.then do |f|
      f.issue = 85
      f.repository = 695
      f.what = 'issue-was-opened'
      f.when = Time.parse('2024-09-08T15:00:00Z')
      f.where = 'gitlab'
      f.who = 257_962
    end
    VCR.use_cassette('find-all-issues/find-all-issues') do
      load_it('find-all-issues', fb)
    end
    assert_equal(6, fb.query('(always)').each.to_a.size)
    fb.query("(eq what 'iterate')").each.first.then do |f|
      assert_equal('github', f.where)
      assert_equal(695, f.repository)
      assert_equal(87, f.min_issue_was_found)
    end
    fs = fb.query("(eq what 'issue-was-opened')").each.to_a
    assert_equal(5, fs.count)
    fs[-2].then do |f|
      assert_nil(f[:event_id])
      assert_nil(f[:event_type])
      assert_equal('The issue foo/foo#42 has been earlier opened by @yegor256.', f.details)
      assert_equal(42, f.issue)
      assert_equal(695, f.repository)
      assert_equal('issue-was-opened', f.what)
      assert_equal(Time.parse('2024-09-04 17:00:00 UTC'), f.when)
      assert_equal('github', f.where)
      assert_equal(526_301, f.who)
    end
    fs[-1].then do |f|
      assert_nil(f[:event_id])
      assert_nil(f[:event_type])
      assert_equal('The issue foo/foo#45 has been earlier opened by @yegor257.', f.details)
      assert_equal(45, f.issue)
      assert_equal(695, f.repository)
      assert_equal('issue-was-opened', f.what)
      assert_equal(Time.parse('2024-09-04 18:00:00 UTC'), f.when)
      assert_equal('github', f.where)
      assert_equal(526_302, f.who)
    end
  end

  def test_end_of_iteration_leave_old_marker_instead_reset_to_zero
    rate_limit_up
    fb = Factbase.new
    fb.insert.then do |f|
      f._id = 1
      f.repository = 991
      f.what = 'iterate'
      f.where = 'github'
      f.min_issue_was_found = 44
    end
    fb.insert.then do |f|
      f._id = 2
      f.issue = 44
      f.repository = 991
      f.what = 'issue-was-opened'
      f.where = 'github'
    end
    fb.insert.then do |f|
      f._id = 3
      f.issue = 45
      f.repository = 991
      f.what = 'issue-was-opened'
      f.where = 'github'
    end
    VCR.use_cassette('find-all-issues/end-of-iteration-leave-old-marker-instead-reset-to-zero') do
      load_it('find-all-issues', fb)
    end
    assert_equal(3, fb.size)
    refute_equal(0, fb.query('(eq what "iterate")').each.to_a.first.min_issue_was_found)
    assert_equal(45, fb.query('(eq what "iterate")').each.to_a.first.min_issue_was_found)
  end

  def test_when_issue_response_has_empty_created_at
    rate_limit_up
    fb = Factbase.new
    fb.insert.then do |f|
      f._id = 1
      f.repository = 991
      f.what = 'iterate'
      f.where = 'github'
      f.min_issue_was_found = 5
    end
    fb.insert.then do |f|
      f._id = 2
      f.issue = 11
      f.repository = 991
      f.what = 'issue-was-opened'
      f.where = 'github'
    end
    VCR.use_cassette('find-all-issues/when-issue-response-has-empty-created-at') do
      load_it('find-all-issues', fb)
    end
    assert_equal(2, fb.size)
    assert_equal(5, fb.query('(eq what "iterate")').each.to_a.first.min_issue_was_found)
  end

  def test_paginated_pulls_continue_after_not_found
    rate_limit_up
    fb = Factbase.new
    fb.insert.then do |f|
      f.issue = 45
      f.repository = 991
      f.what = 'pull-was-opened'
      f.where = 'github'
    end
    VCR.use_cassette('find-all-issues/paginated-pulls-continue-after-not-found') do
      load_it('find-all-issues', fb)
    end
    survivor = fb.query("(and (eq issue 46) (eq what 'pull-was-opened'))").each.first
    refute_nil(
      survivor,
      'the second pull must be recorded after the first raises 404 — paginated batch must not truncate on exception'
    )
    assert_equal('feature/branch-survivor', survivor.branch)
  end

  def test_paginated_pulls_continue_after_forbidden
    rate_limit_up
    fb = Factbase.new
    fb.insert.then do |f|
      f.issue = 45
      f.repository = 991
      f.what = 'pull-was-opened'
      f.where = 'github'
    end
    VCR.use_cassette('find-all-issues/paginated-pulls-continue-after-forbidden') do
      load_it('find-all-issues', fb)
    end
    survivor = fb.query("(and (eq issue 46) (eq what 'pull-was-opened'))").each.first
    refute_nil(survivor, 'the second pull must be recorded after the first hits transient forbidden')
    assert_equal('feature/branch-survivor', survivor.branch)
    assert_empty(
      fb.query('(eq what "issue-was-lost")').each.to_a,
      'forbidden is transient — must not produce an issue-was-lost tombstone'
    )
  end

  def test_rescues_forbidden_issue_lookup
    rate_limit_up
    fb = Factbase.new
    fb.insert.then do |f|
      f._id = 1
      f.issue = 87
      f.repository = 695
      f.what = 'issue-was-opened'
      f.where = 'github'
    end
    VCR.use_cassette('find-all-issues/rescues-forbidden-issue-lookup') do
      load_it('find-all-issues', fb)
    end
    fact = fb.query('(eq issue 87)').each.first
    refute_nil(fact, 'seed fact should still be present after 403 rescue')
    assert_nil(
      fact['stale'],
      '403 is transient — fact must NOT be marked stale; next cycle will retry the issue lookup'
    )
  end
end
