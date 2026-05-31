# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../test__helper'

class TestIssueWasUnassigned < Jp::Test
  using SmartFactbase

  def test_not_found_issue_events
    rate_limit_up
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-assigned', repository: 42, issue: 44, where: 'github', who: 421)
    VCR.use_cassette('issue-was-unassigned/not-found-issue-events') do
      load_it('issue-was-unassigned', fb)
    end
    assert_equal(1, fb.picks(what: 'issue-was-assigned').size)
    assert_nil(fb.pick(what: 'issue-was-assigned')['unassigned'])
  end

  def test_without_unassignes_events
    rate_limit_up
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-assigned', repository: 42, issue: 44, where: 'github', who: 421)
    VCR.use_cassette('issue-was-unassigned/without-unassignes-events') do
      load_it('issue-was-unassigned', fb)
    end
    assert_equal(1, fb.picks(what: 'issue-was-assigned').size)
    assert_nil(fb.pick(what: 'issue-was-assigned')['unassigned'])
  end

  def test_with_unassignes_events
    rate_limit_up
    fb = Factbase.new
    fb.with(
      _id: 1, what: 'issue-was-assigned', repository: 42, issue: 44, where: 'github',
      who: 421, when: Time.parse('2025-10-03 17:45:00 UTC')
    )
    VCR.use_cassette('issue-was-unassigned/with-unassignes-events') do
      load_it('issue-was-unassigned', fb)
    end
    assert_equal(1, fb.picks(what: 'issue-was-assigned').size)
    assert_equal(Time.parse('2025-10-05 23:55:00 UTC'), fb.pick(what: 'issue-was-assigned').unassigned)
  end

  def test_rescues_forbidden_on_issue_events_lookup
    rate_limit_up
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-assigned', repository: 42, issue: 44, where: 'github', who: 421)
    VCR.use_cassette('issue-was-unassigned/rescues-forbidden-on-issue-events-lookup') do
      load_it('issue-was-unassigned', fb)
    end
    f = fb.query('(eq issue 44)').each.first
    refute_nil(f)
    assert_nil(
      f['stale'],
      '403 is transient — fact must NOT be marked stale; next cycle will retry the events lookup'
    )
  end
end
