# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require_relative '../../lib/pull_request'
require_relative '../test__helper'

class TestPullRequest < Jp::Test
  def test_fetch_workflows_skips_check_runs_with_nil_app
    rate_limit_up
    $options = Judges::Options.new({})
    $global = {}
    $loog = Loog::NULL
    pr = { number: 44, head: { sha: 'aa123' }, base: { repo: { full_name: 'foo/foo' } } }
    result =
      VCR.use_cassette('lib/pull-request/skips-check-runs-with-nil-app') do
        Jp.fetch_workflows(pr)
      end
    assert_equal({ succeeded_builds: 0, failed_builds: 0 }, result)
  end

  def test_fetch_workflows_counts_github_actions_runs
    rate_limit_up
    $options = Judges::Options.new({})
    $global = {}
    $loog = Loog::NULL
    pr = { number: 55, head: { sha: 'bb456' }, base: { repo: { full_name: 'foo/foo' } } }
    result =
      VCR.use_cassette('lib/pull-request/counts-github-actions-runs') do
        Jp.fetch_workflows(pr)
      end
    assert_equal({ succeeded_builds: 1, failed_builds: 0 }, result)
  end

  def test_counts_reactions_when_reaction_user_is_nil
    rate_limit_up
    $options = Judges::Options.new({})
    $global = {}
    $loog = Loog::NULL
    count =
      VCR.use_cassette('lib/pull-request/counts-reactions-when-reaction-user-is-nil') do
        Jp.count_appreciated_comments(
          { base: { repo: { full_name: 'foo/foo' } } },
          [{ id: 101, user: { id: 7 } }],
          []
        )
      end
    assert_equal(2, count)
  end

  def test_counts_reactions_when_comment_user_is_nil
    rate_limit_up
    $options = Judges::Options.new({})
    $global = {}
    $loog = Loog::NULL
    pr = { base: { repo: { full_name: 'foo/foo' } } }
    count =
      VCR.use_cassette('lib/pull-request/counts-reactions-when-comment-user-is-nil') do
        Jp.count_appreciated_comments(pr, [], [{ id: 202, user: nil }])
      end
    assert_equal(1, count)
  end

  def test_count_appreciated_comments_skips_issue_comment_on_octokit_not_found
    WebMock.disable_net_connect!
    rate_limit_up
    $options = Judges::Options.new({})
    $global = {}
    $loog = Loog::NULL
    stub_request(:get, 'https://api.github.com/repos/foo/foo/issues/comments/301/reactions')
      .to_return(status: 404, headers: { 'Content-Type' => 'application/json' }, body: '{}')
    stub_github('https://api.github.com/repos/foo/foo/issues/comments/302/reactions', body: [{ user: { id: 99 } }])
    pr = { base: { repo: { full_name: 'foo/foo' } } }
    count = Jp.count_appreciated_comments(pr, [{ id: 301, user: { id: 1 } }, { id: 302, user: { id: 1 } }], [])
    assert_equal(1, count)
  end

  def test_count_appreciated_comments_skips_issue_comment_on_octokit_forbidden
    WebMock.disable_net_connect!
    rate_limit_up
    $options = Judges::Options.new({})
    $global = {}
    $loog = Loog::NULL
    stub_request(:get, 'https://api.github.com/repos/foo/foo/issues/comments/401/reactions')
      .to_return(status: 403, headers: { 'Content-Type' => 'application/json' }, body: '{}')
    pr = { base: { repo: { full_name: 'foo/foo' } } }
    count = Jp.count_appreciated_comments(pr, [{ id: 401, user: { id: 1 } }], [])
    assert_equal(0, count)
  end

  def test_count_appreciated_comments_skips_code_comment_on_octokit_not_found
    WebMock.disable_net_connect!
    rate_limit_up
    $options = Judges::Options.new({})
    $global = {}
    $loog = Loog::NULL
    stub_request(:get, 'https://api.github.com/repos/foo/foo/pulls/comments/501/reactions')
      .to_return(status: 404, headers: { 'Content-Type' => 'application/json' }, body: '{}')
    stub_github('https://api.github.com/repos/foo/foo/pulls/comments/502/reactions', body: [{ user: { id: 88 } }])
    pr = { base: { repo: { full_name: 'foo/foo' } } }
    count = Jp.count_appreciated_comments(pr, [], [{ id: 501, user: { id: 1 } }, { id: 502, user: { id: 1 } }])
    assert_equal(1, count)
  end

  def test_count_appreciated_comments_skips_code_comment_on_octokit_forbidden
    WebMock.disable_net_connect!
    rate_limit_up
    $options = Judges::Options.new({})
    $global = {}
    $loog = Loog::NULL
    stub_request(:get, 'https://api.github.com/repos/foo/foo/pulls/comments/601/reactions')
      .to_return(status: 403, headers: { 'Content-Type' => 'application/json' }, body: '{}')
    pr = { base: { repo: { full_name: 'foo/foo' } } }
    count = Jp.count_appreciated_comments(pr, [], [{ id: 601, user: { id: 1 } }])
    assert_equal(0, count)
  end
end
