# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../fake_github'
require_relative '../test__helper'

class TestMissingIssueFacts < Jp::Test
  using SmartFactbase

  def test_skips_a_repository_without_issue_numbers
    fb = Factbase.new.with(what: 'iterate', where: 'github', repository: 42)
    scan(fb)
    assert_equal(1, fb.size, 'a repository without issues must keep only its initial fact')
  end

  def test_keeps_the_details_of_an_existing_opening
    fb = gap
    fb.pick(issue: 1).details = 'previously recorded'
    scan(fb, 1)
    assert_equal('previously recorded', fb.pick(issue: 1).details)
    assert(fb.one?(what: 'issue-was-opened', issue: 1), 'the existing opening must remain unique')
  end

  def test_describes_a_newly_discovered_issue
    fb = gap
    scan(fb, 2)
    assert_match(/missing issue .*#2.*opened by a user who has deleted the account/, fb.pick(issue: 2).details)
  end

  private

  def gap
    Factbase.new.with(what: 'issue-was-opened', where: 'github', repository: 42, issue: 1)
      .with(what: 'issue-was-opened', where: 'github', repository: 42, issue: 3)
  end

  def scan(fb, number = nil)
    Jp::FakeGithub.new(
      'GET /rate_limit' => { rate: { remaining: 1000, limit: 1000 } },
      'GET /repositories/42' => { id: 42, full_name: 'foo/foo' },
      'GET /repos/foo/foo/issues/2' => { number:, created_at: '2025-09-27T06:03:16Z' }
    ).run { load_it('find-missing-issues', fb) }
  end
end
