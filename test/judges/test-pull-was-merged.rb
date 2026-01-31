# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
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
    stub_github('https://api.github.com/repos/foo/foo/pulls/44/reviews?per_page=100', body: [])
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
    stub_github('https://api.github.com/repos/foo/foo/pulls/44/reviews?per_page=100', body: [])
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
    stub_github('https://api.github.com/repos/foo/foo/pulls/44/reviews?per_page=100', body: [])
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

  def test_pull_was_merged_with_exist_review
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
      'https://api.github.com/repos/foo/foo/pulls/44/reviews?per_page=100',
      body: [{ id: 123, user: { id: 142, login: 'user2' }, submitted_at: '2025-09-29 05:05:46 UTC' }]
    )
    stub_github('https://api.github.com/repos/foo/foo/pulls/44/reviews/123/comments?per_page=100', body: [])
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/44/comments?per_page=100',
      body: []
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/issues/44/comments?per_page=100',
      body: []
    )
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
          comments: 0, comments_appreciated: 0, comments_by_author: 0, comments_by_reviewers: 0,
          comments_resolved: 0, comments_to_code: 0, succeeded_builds: 0, branch: '40',
          review: Time.parse('2025-09-29 05:05:46 UTC'),
          details: 'Apparently, foo/foo#44 has been "pull-was-closed".'
        )
      )
    end
  end

  def test_pull_was_merged_with_review_code_suggestions
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
      'https://api.github.com/repos/foo/foo/pulls/44/reviews?per_page=100',
      body: [
        { id: 123, user: { id: 422, login: 'user2' }, body: 'Look good!', submitted_at: '2025-09-29 05:05:46 UTC' },
        { id: 124, user: { id: 421, login: 'user' }, body: '', submitted_at: '2025-09-29 05:55:00 UTC' },
        { id: 125, user: { id: 421, login: 'user' }, body: '', submitted_at: '2025-09-29 05:57:00 UTC' },
        { id: 126, user: { id: 422, login: 'user2' }, body: '', submitted_at: '2025-09-29 06:00:00 UTC' },
        { id: 127, user: { id: 422, login: 'user2' }, body: 'Perfect!', submitted_at: '2025-09-29 06:45:00 UTC' }
      ]
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/44/reviews/123/comments?per_page=100',
      body: [
        {
          id: 22_099, pull_request_review_id: 123,
          diff_hunk: '@@ -93,4 +93,65 @@ def some_func...', path: 'lib/some/path/file.rb', commit_id: '3e695',
          body: 'Some question0', created_at: '2025-09-29 05:05:00 UTC', user: { id: 422, login: 'user2' }
        },
        {
          id: 22_100, pull_request_review_id: 123,
          diff_hunk: '@@ -93,4 +93,65 @@ def some_func1...', path: 'lib/some/path/file1.rb', commit_id: '3e695',
          body: 'Some question1', created_at: '2025-09-29 05:06:00 UTC', user: { id: 422, login: 'user2' }
        },
        {
          id: 22_101, pull_request_review_id: 123,
          diff_hunk: '@@ -93,4 +93,65 @@ def some_func2...', path: 'lib/some/path/file2.rb', commit_id: '3e695',
          body: 'Some question2', created_at: '2025-09-29 05:07:00 UTC', user: { id: 422, login: 'user2' }
        }
      ]
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/44/reviews/124/comments?per_page=100',
      body: [
        {
          id: 22_103, pull_request_review_id: 124,
          diff_hunk: '@@ -93,4 +93,65 @@ def some_func...', path: 'lib/some/path/file1.rb', commit_id: '3e695',
          body: 'Some answer1', created_at: '2025-09-29 05:45:00 UTC', user: { id: 421, login: 'user' },
          in_reply_to_id: 22_100
        }
      ]
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/44/reviews/125/comments?per_page=100',
      body: [
        {
          id: 22_104, pull_request_review_id: 125,
          diff_hunk: '@@ -93,4 +93,65 @@ def some_func...', path: 'lib/some/path/file1.rb', commit_id: '3e695',
          body: 'Some answer2', created_at: '2025-09-29 05:56:00 UTC', user: { id: 421, login: 'user' },
          in_reply_to_id: 22_100
        }
      ]
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/44/reviews/126/comments?per_page=100',
      body: [
        {
          id: 22_105, pull_request_review_id: 126,
          diff_hunk: '@@ -93,4 +93,65 @@ def some_func...', path: 'lib/some/path/file1.rb', commit_id: '3e695',
          body: 'Some question3', created_at: '2025-09-29 05:56:00 UTC', user: { id: 422, login: 'user2' },
          in_reply_to_id: 22_100
        }
      ]
    )
    stub_github('https://api.github.com/repos/foo/foo/pulls/44/reviews/127/comments?per_page=100', body: [])
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/44/comments?per_page=100',
      body: []
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/issues/44/comments?per_page=100',
      body: []
    )
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
          comments: 0, comments_appreciated: 0, comments_by_author: 0, comments_by_reviewers: 0,
          comments_resolved: 0, comments_to_code: 0, succeeded_builds: 0, branch: '40',
          suggestions: 3, review: Time.parse('2025-09-29 05:05:46 UTC'),
          details: 'Apparently, foo/foo#44 has been "pull-was-closed".'
        )
      )
    end
  end
end
