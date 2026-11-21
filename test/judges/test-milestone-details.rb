# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
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
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/repos/foo/foo/milestones?per_page=100&state=all',
      body: [{ number: 7, title: 'Release candidate', created_at: '2025-01-01T12:00:00Z', creator: { id: 421 } }]
    )
    fb = Factbase.new
    fb.with(what: 'issue-was-opened', repository: 42, issue: 44, where: 'github')
    load_it('milestone-was-set', fb)
    fb.pick(what: 'milestone-was-set')
  end
end
