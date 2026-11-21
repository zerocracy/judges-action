# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'fbe/github_graph'
require_relative '../test__helper'

class TestGithubEventAttributes < Jp::Test
  using SmartFactbase

  def test_records_the_branch_of_a_closed_pull
    prepare_pull
    %w[reviews comments].each do |endpoint|
      stub_github("https://api.github.com/repos/foo/foo/pulls/44/#{endpoint}?per_page=100", body: [])
    end
    stub_github('https://api.github.com/repos/foo/foo/issues/44/comments?per_page=100', body: [])
    stub_github('https://api.github.com/repos/foo/foo/commits/abc/check-runs?per_page=100', body: { check_runs: [] })
    fb = scan('PullRequestEvent', { action: 'closed', pull_request: { number: 44 } })
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
    stub_github('https://api.github.com/repos/foo/foo/contributors?per_page=100', body: [])
    stub_github('https://api.github.com/repos/foo/foo/commits?per_page=1', body: [{ sha: 'abc' }])
    stub_github(
      'https://api.github.com/repos/foo/foo/compare/abc...v1.2.3?per_page=100',
      body: { status: 'identical', total_commits: 0, commits: [], files: [] }
    )
    fb = scan('ReleaseEvent', { action: 'published', release: { id: 451, name: 'Release', tag_name: 'v1.2.3' } })
    assert_equal(451, fb.pick(what: 'release-published').release, 'the release ID must come from the event')
  end

  private

  def prepare_pull
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/44',
      body: {
        number: 44, user: { id: 99 }, additions: 10, deletions: 2,
        comments: 0, review_comments: 0, commits: 5, changed_files: 7,
        head: { ref: 'feature-branch', sha: 'abc' },
        base: { repo: { id: 42, full_name: 'foo/foo' } }
      }
    )
  end

  def review
    prepare_pull
    fb =
      scan('PullRequestReviewEvent', { action: 'created', pull_request: { number: 44 }, review: { state: 'approved' } })
    fb.pick(what: 'pull-was-reviewed')
  end

  def scan(type, payload)
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, full_name: 'foo/foo' })
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_github('https://api.github.com/user/42', body: { id: 42, login: 'alice' })
    stub_github(
      'https://api.github.com/repositories/42/events?per_page=100',
      body: [{ id: 123, created_at: '2025-09-30T12:00:00Z', actor: { id: 42 }, repo: { id: 42 }, type:, payload: }]
    )
    fb = Factbase.new
    Fbe.stub(:github_graph, Fbe::Graph::Fake.new) { load_it('github-events', fb) }
    fb
  end
end
