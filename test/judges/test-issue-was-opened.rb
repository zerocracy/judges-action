# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../fake_github'
require_relative '../test__helper'

class TestIssueWasOpened < Jp::Test
  using SmartFactbase

  def test_rescues_forbidden_on_issue_lookup
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-closed', repository: 42, issue: 44, where: 'github')
    Jp::FakeGithub.new(
      'GET /rate_limit' => { resources: { search: { remaining: 30, limit: 30 } }, rate: { remaining: 1000 } },
      'GET /repos/foo/foo' => { id: 42, full_name: 'foo/foo' },
      'GET /repositories/42' => { id: 42, full_name: 'foo/foo' },
      'GET /repos/foo/foo/issues/44' => [403, { message: 'Resource not accessible by integration' }]
    ).run do
      load_it('issue-was-opened', fb)
    end
    assert_nil(
      fb.pick(issue: 44)['stale'],
      'the fact is stale after a transient 403, while the next cycle must retry the lookup'
    )
  end

  def test_survives_an_issue_whose_author_is_gone
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-closed', repository: 42, issue: 44, where: 'github')
    Jp::FakeGithub.new(
      'GET /rate_limit' => { resources: { search: { remaining: 30, limit: 30 } }, rate: { remaining: 1000 } },
      'GET /repositories/42' => { id: 42, full_name: 'foo/foo' },
      'GET /repos/foo/foo' => { id: 42, full_name: 'foo/foo' },
      'GET /repos/foo/foo/issues/44' => {
        number: 44, created_at: Time.parse('2025-01-01 12:00:00 UTC'), user: nil
      }
    ).run do
      load_it('issue-was-opened', fb)
    end
    f = fb.picks(what: 'issue-was-opened').first
    refute_nil(f, 'no fact was made for an issue whose author deleted the account')
    assert_equal('who', f['stale'].first)
  end

  def test_finds_the_opening_for_rewards_and_resolutions
    %w[
      bug-was-resolved enhancement-suggestion-was-rewarded bug-report-was-rewarded enhancement-was-accepted
    ].each do |kind|
      fb = Factbase.new
      fb.with(_id: 1, what: kind, repository: 42, issue: 44, where: 'github')
      opened(fb)
      assert_equal(1, fb.picks(what: 'issue-was-opened', issue: 44).count, "no opening was found for #{kind}")
    end
  end

  def test_stamps_the_opening_with_the_creation_time_of_the_issue
    fb = Factbase.new
    fb.with(_id: 1, what: 'bug-report-was-rewarded', repository: 42, issue: 44, where: 'github')
    opened(fb)
    assert_equal(
      Time.parse('2025-01-01 12:00:00 UTC'), fb.picks(what: 'issue-was-opened').first.when,
      'the opening must be dated when GitHub created the issue, not when the judge ran'
    )
  end

  def test_does_not_open_twice_for_a_rewarded_bug_report
    fb = Factbase.new
    fb.with(_id: 1, what: 'bug-report-was-rewarded', repository: 42, issue: 44, where: 'github')
      .with(_id: 2, what: 'issue-was-opened', repository: 42, issue: 44, where: 'github')
    opened(fb)
    assert_equal(1, fb.picks(what: 'issue-was-opened', issue: 44).count, 'a second opening was made')
  end

  def test_rescues_not_found_on_repo_name_lookup
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-closed', repository: 42, issue: 44, where: 'github')
    Jp::FakeGithub.new(
      'GET /rate_limit' => { resources: { search: { remaining: 30, limit: 30 } }, rate: { remaining: 1000 } },
      'GET /repositories/42' => [404, { message: 'Not Found' }]
    ).run do
      load_it('issue-was-opened', fb)
    end
    assert(
      fb.none?(what: 'issue-was-opened'),
      'a vanished repository produced facts, while the judge must make none and not abort'
    )
  end

  private

  def opened(fb)
    Jp::FakeGithub.new(
      'GET /rate_limit' => { resources: { search: { remaining: 30, limit: 30 } }, rate: { remaining: 1000 } },
      'GET /repositories/42' => { id: 42, full_name: 'foo/foo' },
      'GET /repos/foo/foo' => { id: 42, full_name: 'foo/foo' },
      'GET /repos/foo/foo/issues/44' => {
        number: 44, created_at: Time.parse('2025-01-01 12:00:00 UTC'), user: { id: 45, login: 'jeff' }
      },
      'GET /user/45' => { id: 45, login: 'jeff' }
    ).run do
      load_it('issue-was-opened', fb)
    end
  end
end
