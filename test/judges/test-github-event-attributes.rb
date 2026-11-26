# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'fbe/github_graph'
require_relative '../fake_github'
require_relative '../test__helper'

class TestGithubEventAttributes < Jp::Test
  using SmartFactbase

  def test_records_the_branch_of_a_closed_pull
    fb = scan(
      'PullRequestEvent', { action: 'closed', pull_request: { number: 44 } },
      'GET /repos/foo/foo/pulls/44' => pull,
      'GET /repos/foo/foo/pulls/44/reviews?per_page=100' => [],
      'GET /repos/foo/foo/pulls/44/comments?per_page=100' => [],
      'GET /repos/foo/foo/issues/44/comments?per_page=100' => [],
      'GET /repos/foo/foo/commits/abc/check-runs?per_page=100' => { check_runs: [] }
    )
    assert_equal('feature-branch', fb.pick(what: 'pull-was-closed').branch)
  end

  def test_records_the_commit_count_of_a_reviewed_pull
    assert_equal(5, review.commits, 'the review fact must keep the pull commit count')
  end

  def test_records_the_file_count_of_a_reviewed_pull
    assert_equal(7, review.files, 'the review fact must keep the pull changed-file count')
  end

  def test_describes_an_opened_issue
    fb = scan('IssuesEvent', { action: 'opened', issue: { number: 44 } })
    assert_match(%r{foo/foo#44\b.*opened.*@alice\b}, fb.pick(what: 'issue-was-opened').details)
  end

  def test_describes_a_closed_issue
    fb = scan('IssuesEvent', { action: 'closed', issue: { number: 44 } })
    assert_match(%r{foo/foo#44\b.*closed.*@alice\b}, fb.pick(what: 'issue-was-closed').details)
  end

  def test_describes_a_created_tag
    fb = scan('CreateEvent', { ref_type: 'tag', ref: 'v1.2.3' })
    assert_match(%r{v1\.2\.3.*foo/foo.*@alice\b}, fb.pick(what: 'tag-was-created').details)
  end

  def test_records_the_published_release_id
    fb = scan(
      'ReleaseEvent', { action: 'published', release: { id: 451, name: 'Release', tag_name: 'v1.2.3' } },
      'GET /repos/foo/foo/contributors?per_page=100' => [],
      'GET /repos/foo/foo/commits?per_page=1' => [{ sha: 'abc' }],
      'GET /repos/foo/foo/compare/abc...v1.2.3?per_page=100' => {
        status: 'identical', total_commits: 0, commits: [], files: []
      }
    )
    assert_equal(451, fb.pick(what: 'release-published').release, 'the release ID must come from the event')
  end

  private

  def pull
    {
      number: 44, user: { id: 99 }, additions: 10, deletions: 2,
      comments: 0, review_comments: 0, commits: 5, changed_files: 7,
      head: { ref: 'feature-branch', sha: 'abc' },
      base: { repo: { id: 42, full_name: 'foo/foo' } }
    }
  end

  def review
    fb = scan(
      'PullRequestReviewEvent', { action: 'created', pull_request: { number: 44 }, review: { state: 'approved' } },
      'GET /repos/foo/foo/pulls/44' => pull
    )
    fb.pick(what: 'pull-was-reviewed')
  end

  def scan(type, payload, routes = {})
    fb = Factbase.new
    event = { id: 123, created_at: '2025-09-30T12:00:00Z', actor: { id: 42 }, repo: { id: 42 }, type:, payload: }
    Jp::FakeGithub.new(
      'GET /rate_limit' => {
        resources: { search: { remaining: 30, limit: 30 } }, rate: { remaining: 1000, limit: 1000 }
      },
      'GET /repos/foo/foo' => { id: 42, full_name: 'foo/foo' },
      'GET /repositories/42' => { id: 42, full_name: 'foo/foo' },
      'GET /user/42' => { id: 42, login: 'alice' },
      'GET /repositories/42/events?per_page=100' => [event],
      **routes
    ).run do
      Fbe.stub(:github_graph, Fbe::Graph::Fake.new) { load_it('github-events', fb) }
    end
    fb
  end
end
