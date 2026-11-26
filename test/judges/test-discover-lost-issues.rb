# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'fbe/tombstone'
require 'uri'
require_relative '../fake_github'
require_relative '../test__helper'

class TestDiscoverLostIssues < Jp::Test
  using SmartFactbase

  def test_marks_a_closed_issue_lost_when_looking_up_its_opening
    lost('issue-was-opened', seed('issue-was-closed'))
  end

  def test_marks_an_open_issue_lost_when_looking_up_its_closure
    lost('issue-was-closed', seed('issue-was-opened'))
  end

  def test_marks_a_reviewed_pull_lost_when_looking_up_its_issue
    lost('pull-was-opened', seed('pull-was-reviewed'))
  end

  def test_marks_a_missing_pull_lost_after_searching_all_issues
    fb = seed('pull-was-opened', 1)
    query = URI.encode_www_form_component('repo:foo/foo type:pull created:>=2025-09-27')
    lost(
      'find-all-issues', fb,
      'GET /repos/foo/foo/issues/1' => { created_at: pull[:created_at] },
      "GET /search/issues?order=asc&per_page=100&q=#{query}&sort=created" => {
        total_count: 1, incomplete_results: false, items: [pull]
      }
    )
  end

  def test_marks_a_missing_earliest_pull_lost
    lost(
      'find-earliest-issue', Factbase.new,
      'GET /repos/foo/foo/issues?direction=asc&page=1&per_page=1&sort=created&state=all' => [pull]
    )
  end

  def test_marks_a_missing_latest_pull_lost
    lost(
      'find-latest-issue', Factbase.new,
      'GET /repos/foo/foo/issues?direction=desc&page=1&per_page=1&sort=created&state=all' => [pull]
    )
  end

  def test_marks_an_issue_lost_when_its_response_has_no_number
    lost('find-missing-issues', gap, 'GET /repos/foo/foo/issues/2' => {})
  end

  def test_marks_a_missing_pull_lost_when_filling_a_gap
    lost('find-missing-issues', gap, 'GET /repos/foo/foo/issues/2' => pull)
  end

  private

  def seed(what, issue = 2)
    Factbase.new.with(what:, issue:, where: 'github', repository: 42)
  end

  def gap
    seed('issue-was-opened', 1).with(what: 'issue-was-opened', issue: 3, where: 'github', repository: 42)
  end

  def pull
    {
      number: 2, pull_request: { url: 'https://api.github.com/repos/foo/foo/pulls/2' },
      created_at: '2025-09-27T06:03:16Z'
    }
  end

  def lost(judge, fb, routes = {})
    repo = { id: 42, full_name: 'foo/foo' }
    Jp::FakeGithub.new(
      'GET /rate_limit' => {
        rate: { remaining: 1000, limit: 1000 }, resources: { search: { remaining: 30, limit: 30 } }
      },
      'GET /repos/foo/foo' => repo,
      'GET /repositories/42' => repo,
      **routes
    ).run { load_it(judge, fb) }
    assert(Fbe::Tombstone.new(fb:).has?('github', 42, 2), "#{judge} must bury issue 2 after it disappears")
    assert(fb.has?(where: 'github', repository: 42, issue: 2, stale: 'issue'), "#{judge} must mark the issue stale")
  end
end
