# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../test__helper'

class TestLabelWasAttached < Jp::Test
  using SmartFactbase

  def test_label_was_attached_with_duplicate_labeled_event
    rate_limit_up
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, issue: 44, where: 'github')
    fb.with(_id: 2, what: 'issue-was-opened', repository: 42, issue: 45, where: 'github')
    VCR.use_cassette('label-was-attached/label-was-attached-with-duplicate-labeled-event') do
      load_it('label-was-attached', fb)
    end
    assert(fb.one?(what: 'label-was-attached', repository: 42, issue: 44, where: 'github', label: 'bug', who: 421))
    assert(fb.one?(what: 'issue-was-opened', repository: 42, issue: 45, where: 'github', stale: 'issue'))
  end

  def test_rescues_forbidden_on_timeline_lookup
    rate_limit_up
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, issue: 44, where: 'github')
    VCR.use_cassette('label-was-attached/rescues-forbidden-on-timeline-lookup') do
      load_it('label-was-attached', fb)
    end
    f = fb.query('(eq issue 44)').each.first
    refute_nil(f)
    assert_nil(
      f['stale'],
      '403 is transient — fact must NOT be marked stale; next cycle will retry the timeline lookup'
    )
  end

  def test_attaches_each_tracked_label_and_ignores_others
    rate_limit_up
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, issue: 44, where: 'github')
    VCR.use_cassette('label-was-attached/attaches-each-tracked-label-and-ignores-others') do
      load_it('label-was-attached', fb)
    end
    assert(fb.one?(what: 'label-was-attached', repository: 42, issue: 44, where: 'github', label: 'bug', who: 421))
    assert(
      fb.one?(what: 'label-was-attached', repository: 42, issue: 44, where: 'github', label: 'enhancement', who: 421)
    )
    assert(fb.one?(what: 'label-was-attached', repository: 42, issue: 44, where: 'github', label: 'question', who: 422))
    assert_equal(
      0,
      fb.query("(and (eq what 'label-was-attached') (eq label 'wontfix'))").each.to_a.size,
      'untracked labels (not bug/enhancement/question) must be ignored'
    )
  end

  def test_ignores_labeled_event_without_label_payload
    rate_limit_up
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, issue: 44, where: 'github')
    VCR.use_cassette('label-was-attached/ignores-labeled-event-without-label-payload') do
      load_it('label-was-attached', fb)
    end
    assert_equal(0, fb.query("(eq what 'label-was-attached')").each.to_a.size)
  end

  def test_attaches_label_without_actor_payload
    rate_limit_up
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, issue: 44, where: 'github')
    VCR.use_cassette('label-was-attached/attaches-label-without-actor-payload') do
      load_it('label-was-attached', fb)
    end
    f = fb.query("(and (eq what 'label-was-attached') (eq label 'bug'))").each.first
    refute_nil(f)
    assert_nil(f['who'])
    assert_equal(['who'], f['stale'])
  end

  def test_marks_stale_when_timeline_returns_not_found
    rate_limit_up
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, issue: 44, where: 'github')
    VCR.use_cassette('label-was-attached/marks-stale-when-timeline-returns-not-found') do
      load_it('label-was-attached', fb)
    end
    assert(
      fb.one?(what: 'issue-was-opened', repository: 42, issue: 44, where: 'github', stale: 'issue'),
      '404 is permanent — issue must be marked stale via Jp.issue_was_lost'
    )
  end
end
