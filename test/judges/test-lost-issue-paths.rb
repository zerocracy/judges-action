# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'fbe/tombstone'
require_relative '../fake_github'
require_relative '../test__helper'

class TestLostIssuePaths < Jp::Test
  using SmartFactbase

  {
    'fix-missing-hoc' => ['pull-was-merged', 'pulls/44'],
    'fix-missing-branch' => ['pull-was-opened', 'pulls/44'],
    'fix-missing-comments' => ['pull-was-closed', 'pulls/44'],
    'issue-was-unassigned' => ['issue-was-assigned', 'issues/44/events'],
    'add-review-comments' => ['pull-was-reviewed', 'pulls/44'],
    'fix-wrong-closures' => ['pull-was-closed', 'pulls/44']
  }.each do |judge, (what, endpoint)|
    define_method("test_#{judge.tr('-', '_')}_marks_missing_issue_stale") do
      fb = missing_issue(judge, what, endpoint)
      assert_equal(
        ['issue'], fb.pick(_id: 1)['stale'],
        "#{judge} must retire the fact after the GitHub issue disappears"
      )
    end
    define_method("test_#{judge.tr('-', '_')}_buries_missing_issue") do
      fb = missing_issue(judge, what, endpoint)
      assert(
        Fbe::Tombstone.new(fb: fb).has?('github', 42, 44),
        "#{judge} must prevent rediscovery of the missing issue"
      )
    end
  end

  private

  def missing_issue(judge, what, endpoint)
    fb = Factbase.new
    fb.with(
      _id: 1, what: what, repository: 42, issue: 44, where: 'github',
      who: 123, when: Time.parse('2025-01-01T00:00:00Z')
    )
    Jp::FakeGithub.new(
      'GET /rate_limit' => { rate: { remaining: 1000, limit: 1000 } },
      'GET /repos/foo/foo' => { id: 42, full_name: 'foo/foo' },
      'GET /repositories/42' => { id: 42, full_name: 'foo/foo' },
      "GET /repos/foo/foo/#{endpoint}" => [404, { message: 'Not Found' }]
    ).run do
      load_it(judge, fb)
    end
    fb
  end
end
