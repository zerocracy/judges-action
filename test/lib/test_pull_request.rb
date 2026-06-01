# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require_relative '../../lib/pull_request'
require_relative '../test__helper'

class TestPullRequest < Jp::Test
  def test_fetch_workflows_skips_check_runs_with_nil_app
    WebMock.disable_net_connect!
    rate_limit_up
    $options = Judges::Options.new({})
    $global = {}
    $loog = Loog::NULL
    pr = { number: 44, head: { sha: 'aa123' }, base: { repo: { full_name: 'foo/foo' } } }
    stub_github(
      'https://api.github.com/repos/foo/foo/commits/aa123/check-runs?per_page=100',
      body: {
        check_runs: [
          { id: 1, app: nil },
          { id: 2, app: { slug: 'some-other-app' } }
        ]
      }
    )
    result = Jp.fetch_workflows(pr)
    assert_equal({ succeeded_builds: 0, failed_builds: 0 }, result)
  end

  def test_fetch_workflows_counts_github_actions_runs
    WebMock.disable_net_connect!
    rate_limit_up
    $options = Judges::Options.new({})
    $global = {}
    $loog = Loog::NULL
    pr = { number: 55, head: { sha: 'bb456' }, base: { repo: { full_name: 'foo/foo' } } }
    stub_github(
      'https://api.github.com/repos/foo/foo/commits/bb456/check-runs?per_page=100',
      body: {
        check_runs: [
          { id: 1, app: nil },
          { id: 2, app: { slug: 'github-actions' } }
        ]
      }
    )
    stub_github('https://api.github.com/repos/foo/foo/actions/jobs/2', body: { id: 2, run_id: 9001 })
    stub_github(
      'https://api.github.com/repos/foo/foo/actions/runs/9001',
      body: { id: 9001, event: 'pull_request', conclusion: 'success' }
    )
    result = Jp.fetch_workflows(pr)
    assert_equal({ succeeded_builds: 1, failed_builds: 0 }, result)
  end

  def test_fetch_workflows_rescues_not_found_on_check_runs
    WebMock.disable_net_connect!
    rate_limit_up
    $options = Judges::Options.new({})
    $global = {}
    $loog = Loog::NULL
    $judge = 'test-pull-request'
    pr = { number: 66, head: { sha: 'cc789' }, base: { repo: { full_name: 'foo/foo' } } }
    stub_request(:get, 'https://api.github.com/repos/foo/foo/commits/cc789/check-runs?per_page=100')
      .to_return(status: 404, body: { message: 'Not Found' }.to_json, headers: { 'Content-Type' => 'application/json' })
    result = Jp.fetch_workflows(pr)
    assert_equal({ succeeded_builds: 0, failed_builds: 0 }, result)
  end

  def test_fetch_workflows_rescues_forbidden_on_check_runs
    WebMock.disable_net_connect!
    rate_limit_up
    $options = Judges::Options.new({})
    $global = {}
    $loog = Loog::NULL
    $judge = 'test-pull-request'
    pr = { number: 77, head: { sha: 'dd012' }, base: { repo: { full_name: 'foo/foo' } } }
    stub_request(:get, 'https://api.github.com/repos/foo/foo/commits/dd012/check-runs?per_page=100')
      .to_return(status: 403, body: { message: 'Forbidden' }.to_json, headers: { 'Content-Type' => 'application/json' })
    result = Jp.fetch_workflows(pr)
    assert_equal({ succeeded_builds: 0, failed_builds: 0 }, result)
  end

  def test_fetch_workflows_skips_run_when_workflow_run_job_not_found
    WebMock.disable_net_connect!
    rate_limit_up
    $options = Judges::Options.new({})
    $global = {}
    $loog = Loog::NULL
    $judge = 'test-pull-request'
    pr = { number: 88, head: { sha: 'ee345' }, base: { repo: { full_name: 'foo/foo' } } }
    stub_github(
      'https://api.github.com/repos/foo/foo/commits/ee345/check-runs?per_page=100',
      body: {
        check_runs: [
          { id: 10, app: { slug: 'github-actions' } },
          { id: 20, app: { slug: 'github-actions' } }
        ]
      }
    )
    stub_request(:get, 'https://api.github.com/repos/foo/foo/actions/jobs/10')
      .to_return(status: 404, body: { message: 'Not Found' }.to_json, headers: { 'Content-Type' => 'application/json' })
    stub_github('https://api.github.com/repos/foo/foo/actions/jobs/20', body: { id: 20, run_id: 7777 })
    stub_github(
      'https://api.github.com/repos/foo/foo/actions/runs/7777',
      body: { id: 7777, event: 'pull_request', conclusion: 'failure' }
    )
    result = Jp.fetch_workflows(pr)
    assert_equal({ succeeded_builds: 0, failed_builds: 1 }, result)
  end

  def test_fetch_workflows_skips_run_when_workflow_run_forbidden
    WebMock.disable_net_connect!
    rate_limit_up
    $options = Judges::Options.new({})
    $global = {}
    $loog = Loog::NULL
    $judge = 'test-pull-request'
    pr = { number: 99, head: { sha: 'ff678' }, base: { repo: { full_name: 'foo/foo' } } }
    stub_github(
      'https://api.github.com/repos/foo/foo/commits/ff678/check-runs?per_page=100',
      body: {
        check_runs: [
          { id: 30, app: { slug: 'github-actions' } }
        ]
      }
    )
    stub_github('https://api.github.com/repos/foo/foo/actions/jobs/30', body: { id: 30, run_id: 5555 })
    stub_request(:get, 'https://api.github.com/repos/foo/foo/actions/runs/5555')
      .to_return(status: 403, body: { message: 'Forbidden' }.to_json, headers: { 'Content-Type' => 'application/json' })
    result = Jp.fetch_workflows(pr)
    assert_equal({ succeeded_builds: 0, failed_builds: 0 }, result)
  end

  def test_counts_reactions_when_reaction_user_is_nil
    WebMock.disable_net_connect!
    rate_limit_up
    $options = Judges::Options.new({})
    $global = {}
    $loog = Loog::NULL
    stub_github(
      'https://api.github.com/repos/foo/foo/issues/comments/101/reactions',
      body: [
        { user: nil },
        { user: { id: 42 } }
      ]
    )
    count = Jp.count_appreciated_comments(
      { base: { repo: { full_name: 'foo/foo' } } },
      [{ id: 101, user: { id: 7 } }],
      []
    )
    assert_equal(2, count)
  end

  def test_counts_reactions_when_comment_user_is_nil
    WebMock.disable_net_connect!
    rate_limit_up
    $options = Judges::Options.new({})
    $global = {}
    $loog = Loog::NULL
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/comments/202/reactions',
      body: [
        { user: { id: 42 } },
        { user: nil }
      ]
    )
    pr = { base: { repo: { full_name: 'foo/foo' } } }
    count = Jp.count_appreciated_comments(pr, [], [{ id: 202, user: nil }])
    assert_equal(1, count)
  end
end
