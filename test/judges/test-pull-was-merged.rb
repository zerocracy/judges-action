# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'fbe/github_graph'
require_relative '../test__helper'

# Test.
class TestPullWasMerged < Jp::Test
  using SmartFactbase

  def test_pull_was_merged_with_nil_user_in_issue_comments
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, name: 'foo', full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/44',
      body: {
        id: 50, number: 44, user: { id: 421, login: 'user' }, state: 'closed',
        closed_at: Time.parse('2025-09-30 18:00:00 UTC'),
        closed_by: { login: 'user2', id: 422 },
        created_at: Time.parse('2025-09-30 15:35:30 UTC'),
        additions: 12, deletions: 5,
        head: { ref: '40', sha: 'aa123' },
        base: { repo: { id: 42, full_name: 'foo/foo' } }
      }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/issues/44',
      body: {
        number: 50, title: 'some title 50', state: 'closed',
        closed_at: Time.parse('2025-09-30 18:00:00 UTC'),
        closed_by: { login: 'user2', id: 422 }
      }
    )
    stub_github('https://api.github.com/repos/foo/foo/pulls/44/comments?per_page=100', body: [])
    stub_github(
      'https://api.github.com/repos/foo/foo/issues/44/comments?per_page=100',
      body: [{ id: 100, user: nil }]
    )
    stub_github('https://api.github.com/repos/foo/foo/issues/comments/100/reactions', body: [])
    stub_github(
      'https://api.github.com/repos/foo/foo/commits/aa123/check-runs?per_page=100', body: { check_runs: [] }
    )
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-opened', repository: 42, issue: 44, where: 'github')
    Fbe.stub(:github_graph, Fbe::Graph::Fake.new) do
      load_it('pull-was-merged', fb)
      assert(
        fb.one?(
          what: 'pull-was-closed', where: 'github', who: 422, repository: 42, issue: 44, hoc: 17,
          comments: 0, comments_appreciated: 0, comments_by_author: 0, comments_by_reviewers: 1,
          comments_resolved: 0, comments_to_code: 0, succeeded_builds: 0, branch: '40',
          details: 'Apparently, foo/foo#44 has been "pull-was-closed".'
        )
      )
    end
  end

  def test_pull_was_merged_with_nil_user_in_pull_request_comments
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, name: 'foo', full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/44',
      body: {
        id: 50, number: 44, user: { id: 421, login: 'user' }, state: 'closed',
        closed_at: Time.parse('2025-09-30 18:00:00 UTC'),
        closed_by: { login: 'user2', id: 422 },
        created_at: Time.parse('2025-09-30 15:35:30 UTC'),
        additions: 12, deletions: 5,
        head: { ref: '40', sha: 'aa123' },
        base: { repo: { id: 42, full_name: 'foo/foo' } }
      }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/issues/44',
      body: {
        number: 50, title: 'some title 50', state: 'closed',
        closed_at: Time.parse('2025-09-30 18:00:00 UTC'),
        closed_by: { login: 'user2', id: 422 }
      }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/44/comments?per_page=100',
      body: [{ id: 100, user: nil }]
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/issues/44/comments?per_page=100',
      body: []
    )
    # stub_github('https://api.github.com/repos/foo/foo/issues/comments/100/reactions', body: [])
    stub_github('https://api.github.com/repos/foo/foo/pulls/comments/100/reactions', body: [])
    stub_github(
      'https://api.github.com/repos/foo/foo/commits/aa123/check-runs?per_page=100', body: { check_runs: [] }
    )
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-opened', repository: 42, issue: 44, where: 'github')
    Fbe.stub(:github_graph, Fbe::Graph::Fake.new) do
      load_it('pull-was-merged', fb)
      assert(
        fb.one?(
          what: 'pull-was-closed', where: 'github', who: 422, repository: 42, issue: 44, hoc: 17,
          comments: 0, comments_appreciated: 0, comments_by_author: 0, comments_by_reviewers: 1,
          comments_resolved: 0, comments_to_code: 1, succeeded_builds: 0, branch: '40',
          details: 'Apparently, foo/foo#44 has been "pull-was-closed".'
        )
      )
    end
  end

  def test_pull_was_merged_with_multiple_facts_with_identical_repository_and_issue
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, name: 'foo', full_name: 'foo/foo' })
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/44',
      body: {
        id: 50, number: 44, user: { id: 421, login: 'user' }, state: 'closed',
        closed_at: Time.parse('2025-10-03 18:00:00 UTC'),
        closed_by: { login: 'user2', id: 422 },
        created_at: Time.parse('2025-10-03 15:35:30 UTC'),
        additions: 12, deletions: 5,
        head: { ref: '40', sha: 'aa123' },
        base: { repo: { id: 42, full_name: 'foo/foo' } }
      }
    )
    stub_github('https://api.github.com/repos/foo/foo/pulls/44/comments?per_page=100', body: [])
    stub_github('https://api.github.com/repos/foo/foo/issues/44/comments?per_page=100', body: [])
    stub_github(
      'https://api.github.com/repos/foo/foo/commits/aa123/check-runs?per_page=100', body: { check_runs: [] }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/issues/44',
      body: {
        number: 44, title: 'some title 44', state: 'closed',
        closed_at: Time.parse('2025-10-03 18:00:00 UTC'),
        closed_by: { login: 'user2', id: 422 }
      }
    )
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-opened', repository: 42, issue: 44, where: 'github')
      .with(_id: 2, what: 'pull-was-reviewed', repository: 42, issue: 44, where: 'github')
    Fbe.stub(:github_graph, Fbe::Graph::Fake.new) do
      load_it('pull-was-merged', fb)
      assert(
        fb.one?(
          what: 'pull-was-closed', where: 'github', who: 422, repository: 42, issue: 44, hoc: 17,
          comments: 0, comments_appreciated: 0, comments_by_author: 0, comments_by_reviewers: 0,
          comments_resolved: 0, comments_to_code: 0, succeeded_builds: 0, branch: '40',
          details: 'Apparently, foo/foo#44 has been "pull-was-closed".'
        )
      )
    end
  end
end
