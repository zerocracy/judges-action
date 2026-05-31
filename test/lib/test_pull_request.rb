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
end
