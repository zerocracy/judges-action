# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../fake_github'
require_relative '../test__helper'

class TestMilestoneDetails < Jp::Test
  using SmartFactbase

  def test_records_github_as_the_milestone_source
    assert_equal('github', milestone.where, 'milestone facts must keep their GitHub source')
  end

  def test_describes_the_milestone_number_and_title
    assert_match(/#7\b.*\bRelease candidate\b/, milestone.details)
  end

  private

  def milestone
    fb = Factbase.new
    fb.with(what: 'issue-was-opened', repository: 42, issue: 44, where: 'github')
    Jp::FakeGithub.new(
      'GET /rate_limit' => {
        resources: { search: { remaining: 30, limit: 30 } }, rate: { remaining: 1000, limit: 1000 }
      },
      'GET /repositories/42' => { id: 42, full_name: 'foo/foo' },
      'GET /repos/foo/foo' => { id: 42, full_name: 'foo/foo' },
      'GET /repos/foo/foo/milestones?per_page=100&state=all' => [
        { number: 7, title: 'Release candidate', created_at: '2025-01-01T12:00:00Z', creator: { id: 421 } }
      ]
    ).run do
      load_it('milestone-was-set', fb)
    end
    fb.pick(what: 'milestone-was-set')
  end
end
