# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'fbe/github_graph'
require_relative '../test__helper'

class TestPullWasMerged < Jp::Test
  using SmartFactbase

  def test_pull_was_merged_with_nil_user_in_issue_comments
    rate_limit_up
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-opened', repository: 42, issue: 44, where: 'github')
    Fbe.stub(:github_graph, Fbe::Graph::Fake.new) do
      VCR.use_cassette('pull-was-merged/pull-was-merged-with-nil-user-in-issue-comments') do
        load_it('pull-was-merged', fb)
      end
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
    rate_limit_up
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-opened', repository: 42, issue: 44, where: 'github')
    Fbe.stub(:github_graph, Fbe::Graph::Fake.new) do
      VCR.use_cassette('pull-was-merged/pull-was-merged-with-nil-user-in-pull-request-comments') do
        load_it('pull-was-merged', fb)
      end
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
    rate_limit_up
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-opened', repository: 42, issue: 44, where: 'github')
      .with(_id: 2, what: 'pull-was-reviewed', repository: 42, issue: 44, where: 'github')
    Fbe.stub(:github_graph, Fbe::Graph::Fake.new) do
      VCR.use_cassette('pull-was-merged/pull-was-merged-with-multiple-facts-with-identical-repository-and-issue') do
        load_it('pull-was-merged', fb)
      end
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
    rate_limit_up
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-opened', repository: 42, issue: 44, where: 'github')
    Fbe.stub(:github_graph, Fbe::Graph::Fake.new) do
      VCR.use_cassette('pull-was-merged/pull-was-merged-with-exist-review') do
        load_it('pull-was-merged', fb)
      end
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
    rate_limit_up
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-opened', repository: 42, issue: 44, where: 'github')
    Fbe.stub(:github_graph, Fbe::Graph::Fake.new) do
      VCR.use_cassette('pull-was-merged/pull-was-merged-with-review-code-suggestions') do
        load_it('pull-was-merged', fb)
      end
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

  def test_rescues_forbidden_on_pull_request_lookup
    rate_limit_up
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-opened', repository: 42, issue: 44, where: 'github')
    VCR.use_cassette('pull-was-merged/rescues-forbidden-on-pull-request-lookup') do
      load_it('pull-was-merged', fb)
    end
    f = fb.query('(eq issue 44)').each.first
    refute_nil(f)
    assert_nil(f['stale'], '403 is transient — fact must NOT be marked stale; next cycle will retry the pull lookup')
  end

  def test_rescues_not_found_on_pull_request_lookup
    rate_limit_up
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-opened', repository: 42, issue: 44, where: 'github')
    VCR.use_cassette('pull-was-merged/rescues-not-found-on-pull-request-lookup') do
      load_it('pull-was-merged', fb)
    end
    f = fb.query('(eq issue 44)').each.first
    refute_nil(f)
    assert_equal('issue', f.stale, 'Jp.issue_was_lost should mark the fact stale=issue when pull lookup returns 404')
  end

  def test_rescues_forbidden_on_issue_lookup_and_continues
    rate_limit_up
    stub_pull_was_merged_success(45)
    stub_pull_was_merged_base(44)
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-opened', repository: 42, issue: 44, where: 'github')
      .with(_id: 2, what: 'pull-was-opened', repository: 42, issue: 45, where: 'github')
    Fbe.stub(:github_graph, Fbe::Graph::Fake.new) do
      VCR.use_cassette('pull-was-merged/rescues-forbidden-on-issue-lookup-and-continues') do
        load_it('pull-was-merged', fb)
      end
      assert_nil(fb.pick(issue: 44, what: 'pull-was-opened')['stale'])
      assert(fb.none?(issue: 44, what: 'pull-was-merged'))
      assert(fb.one?(issue: 45, what: 'pull-was-merged', repository: 42, where: 'github', who: 422))
    end
  end

  def test_rescues_deprecated_on_issue_lookup
    rate_limit_up
    stub_pull_was_merged_base(44)
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-opened', repository: 42, issue: 44, where: 'github')
    VCR.use_cassette('pull-was-merged/rescues-deprecated-on-issue-lookup') do
      Fbe.stub(:github_graph, Fbe::Graph::Fake.new) { load_it('pull-was-merged', fb) }
    end
    assert_equal('issue', fb.pick(issue: 44, what: 'pull-was-opened').stale)
    assert(fb.none?(issue: 44, what: 'pull-was-merged'))
  end

  def test_rescues_forbidden_on_reviews_lookup_and_continues
    rate_limit_up
    stub_pull_was_merged_success(45)
    stub_pull_was_merged_base(44)
    stub_pull_was_merged_issue(44)
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-opened', repository: 42, issue: 44, where: 'github')
      .with(_id: 2, what: 'pull-was-opened', repository: 42, issue: 45, where: 'github')
    Fbe.stub(:github_graph, Fbe::Graph::Fake.new) do
      VCR.use_cassette('pull-was-merged/rescues-forbidden-on-reviews-lookup-and-continues') do
        load_it('pull-was-merged', fb)
      end
      assert_nil(fb.pick(issue: 44, what: 'pull-was-opened')['stale'])
      assert(fb.none?(issue: 44, what: 'pull-was-merged'))
      assert(fb.one?(issue: 45, what: 'pull-was-merged', repository: 42, where: 'github', who: 422))
    end
  end

  def test_rescues_deprecated_on_reviews_lookup
    rate_limit_up
    stub_pull_was_merged_base(44)
    stub_pull_was_merged_issue(44)
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-opened', repository: 42, issue: 44, where: 'github')
    VCR.use_cassette('pull-was-merged/rescues-deprecated-on-reviews-lookup') do
      Fbe.stub(:github_graph, Fbe::Graph::Fake.new) { load_it('pull-was-merged', fb) }
    end
    assert_equal('issue', fb.pick(issue: 44, what: 'pull-was-opened').stale)
    assert(fb.none?(issue: 44, what: 'pull-was-merged'))
  end

  private

  def stub_pull_was_merged_success(issue)
    stub_pull_was_merged_base(issue)
    stub_pull_was_merged_issue(issue)
    stub_github("https://api.github.com/repos/foo/foo/pulls/#{issue}/reviews?per_page=100", body: [])
    stub_github("https://api.github.com/repos/foo/foo/pulls/#{issue}/comments?per_page=100", body: [])
    stub_github("https://api.github.com/repos/foo/foo/issues/#{issue}/comments?per_page=100", body: [])
    stub_github('https://api.github.com/repos/foo/foo/commits/aa123/check-runs?per_page=100', body: { check_runs: [] })
  end

  def stub_pull_was_merged_base(issue)
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, name: 'foo', full_name: 'foo/foo' })
    stub_github(
      "https://api.github.com/repos/foo/foo/pulls/#{issue}",
      body: {
        id: 50, number: issue, user: { id: 421, login: 'user' }, state: 'closed',
        merged_at: Time.parse('2025-09-30 18:00:00 UTC'),
        closed_at: Time.parse('2025-09-30 18:00:00 UTC'),
        created_at: Time.parse('2025-09-30 15:35:30 UTC'),
        additions: 12, deletions: 5, changed_files: 1,
        head: { ref: '40', sha: 'aa123' },
        base: { repo: { id: 42, full_name: 'foo/foo' } }
      }
    )
  end

  def stub_pull_was_merged_issue(issue)
    stub_github(
      "https://api.github.com/repos/foo/foo/issues/#{issue}",
      body: {
        number: issue, title: "some title #{issue}", state: 'closed',
        closed_at: Time.parse('2025-09-30 18:00:00 UTC'),
        closed_by: { login: 'user2', id: 422 }
      }
    )
  end
end
