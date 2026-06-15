# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require_relative '../../lib/pull_request'
require_relative '../test__helper'

class TestPullRequest < Jp::Test
  def test_fetch_workflows_skips_nil_app_check_runs
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

  def test_fetch_workflows_empty_on_not_found_runs
    WebMock.disable_net_connect!
    rate_limit_up
    $options = Judges::Options.new({})
    $global = {}
    $loog = Loog::NULL
    pr = { number: 44, head: { sha: 'aa123' }, base: { repo: { full_name: 'foo/foo' } } }
    stub_request(:get, 'https://api.github.com/repos/foo/foo/commits/aa123/check-runs?per_page=100')
      .to_return(status: 404, body: '')
    result = Jp.fetch_workflows(pr)
    assert_equal({ succeeded_builds: 0, failed_builds: 0 }, result)
  end

  def test_fetch_workflows_empty_on_forbidden_runs
    WebMock.disable_net_connect!
    rate_limit_up
    $options = Judges::Options.new({})
    $global = {}
    $loog = Loog::NULL
    pr = { number: 44, head: { sha: 'aa123' }, base: { repo: { full_name: 'foo/foo' } } }
    stub_request(:get, 'https://api.github.com/repos/foo/foo/commits/aa123/check-runs?per_page=100')
      .to_return(
        status: 403, body: '{"message": "Forbidden"}',
        headers: { 'Content-Type' => 'application/json' }
      )
    result = Jp.fetch_workflows(pr)
    assert_equal({ succeeded_builds: 0, failed_builds: 0 }, result)
  end

  def test_fetch_workflows_skips_not_found_run_job
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
          { id: 1, app: { slug: 'github-actions' } },
          { id: 2, app: { slug: 'github-actions' } }
        ]
      }
    )
    stub_request(:get, 'https://api.github.com/repos/foo/foo/actions/jobs/1').to_return(status: 404, body: '')
    stub_request(:get, 'https://api.github.com/repos/foo/foo/actions/jobs/2')
      .to_return(
        body: { id: 2, run_id: 9002 }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
    stub_github(
      'https://api.github.com/repos/foo/foo/actions/runs/9002',
      body: { id: 9002, event: 'pull_request', conclusion: 'success' }
    )
    result = Jp.fetch_workflows(pr)
    assert_equal({ succeeded_builds: 1, failed_builds: 0 }, result)
  end

  def test_fetch_workflows_skips_forbidden_run_job
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
          { id: 1, app: { slug: 'github-actions' } },
          { id: 2, app: { slug: 'github-actions' } }
        ]
      }
    )
    stub_request(:get, 'https://api.github.com/repos/foo/foo/actions/jobs/1')
      .to_return(
        status: 403, body: '{"message": "Forbidden"}',
        headers: { 'Content-Type' => 'application/json' }
      )
    stub_request(:get, 'https://api.github.com/repos/foo/foo/actions/jobs/2')
      .to_return(
        body: { id: 2, run_id: 9002 }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
    stub_github(
      'https://api.github.com/repos/foo/foo/actions/runs/9002',
      body: { id: 9002, event: 'pull_request', conclusion: 'success' }
    )
    result = Jp.fetch_workflows(pr)
    assert_equal({ succeeded_builds: 1, failed_builds: 0 }, result)
  end

  def test_fetch_workflows_skips_not_found_run
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
          { id: 1, app: { slug: 'github-actions' } },
          { id: 2, app: { slug: 'github-actions' } }
        ]
      }
    )
    stub_request(:get, 'https://api.github.com/repos/foo/foo/actions/jobs/1')
      .to_return(
        body: { id: 1, run_id: 9001 }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
    stub_request(:get, 'https://api.github.com/repos/foo/foo/actions/jobs/2')
      .to_return(
        body: { id: 2, run_id: 9002 }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
    stub_request(:get, 'https://api.github.com/repos/foo/foo/actions/runs/9001').to_return(status: 404, body: '')
    stub_github(
      'https://api.github.com/repos/foo/foo/actions/runs/9002',
      body: { id: 9002, event: 'pull_request', conclusion: 'success' }
    )
    result = Jp.fetch_workflows(pr)
    assert_equal({ succeeded_builds: 1, failed_builds: 0 }, result)
  end

  def test_fetch_workflows_skips_forbidden_run
    WebMock.disable_net_connect!
    rate_limit_up
    $options = Judges::Options.new({})
    $global = {}
    $loog = Loog::NULL
    pr = { number: 55, head: { sha: 'cc456' }, base: { repo: { full_name: 'foo/foo' } } }
    stub_github(
      'https://api.github.com/repos/foo/foo/commits/cc456/check-runs?per_page=100',
      body: {
        check_runs: [
          { id: 3, app: { slug: 'github-actions' } },
          { id: 4, app: { slug: 'github-actions' } }
        ]
      }
    )
    stub_request(:get, 'https://api.github.com/repos/foo/foo/actions/jobs/3')
      .to_return(
        body: { id: 3, run_id: 9003 }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
    stub_request(:get, 'https://api.github.com/repos/foo/foo/actions/jobs/4')
      .to_return(
        body: { id: 4, run_id: 9004 }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
    stub_github('https://api.github.com/repos/foo/foo/actions/runs/9003', status: 403, body: { message: 'Forbidden' })
    stub_github(
      'https://api.github.com/repos/foo/foo/actions/runs/9004',
      body: { id: 9004, event: 'pull_request', conclusion: 'failure' }
    )
    result = Jp.fetch_workflows(pr)
    assert_equal({ succeeded_builds: 0, failed_builds: 1 }, result)
  end

  def test_counts_appreciated_skips_issue_not_found
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

  def test_counts_appreciated_skips_issue_forbidden
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

  def test_counts_appreciated_skips_code_not_found
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

  def test_counts_appreciated_skips_code_forbidden
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

  def test_skips_pr_comments_on_not_found
    WebMock.disable_net_connect!
    rate_limit_up
    $options = Judges::Options.new({})
    $global = {}
    $loog = Loog::NULL
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/1/comments?per_page=100',
      status: 404, body: { message: 'Not Found' }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/issues/1/comments?per_page=100',
      body: [{ id: 10, user: { id: 5 } }]
    )
    stub_github('https://api.github.com/repos/foo/foo/issues/comments/10/reactions', body: [])
    Fbe.stub(:github_graph, Fbe::Graph::Fake.new) do
      pr = { number: 1, comments: 2, review_comments: 1, user: { id: 5 }, base: { repo: { full_name: 'foo/foo' } } }
      info = Jp.comments_info(pr)
      refute_nil(info)
      assert_equal(0, info[:comments_to_code])
    end
  end

  def test_skips_issue_comments_on_forbidden
    WebMock.disable_net_connect!
    rate_limit_up
    $options = Judges::Options.new({})
    $global = {}
    $loog = Loog::NULL
    stub_github('https://api.github.com/repos/foo/foo/pulls/2/comments?per_page=100', body: [])
    stub_github(
      'https://api.github.com/repos/foo/foo/issues/2/comments?per_page=100',
      status: 403, body: { message: 'Forbidden' }
    )
    Fbe.stub(:github_graph, Fbe::Graph::Fake.new) do
      pr = { number: 2, user: { id: 5 }, base: { repo: { full_name: 'foo/foo' } } }
      info = Jp.comments_info(pr)
      refute_nil(info)
      assert_equal(0, info[:comments_by_reviewers])
      assert_equal(0, info[:comments_by_author])
    end
  end

  def test_returns_zeros_on_both_forbidden
    WebMock.disable_net_connect!
    rate_limit_up
    $options = Judges::Options.new({})
    $global = {}
    $loog = Loog::NULL
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/3/comments?per_page=100',
      status: 403, body: { message: 'Forbidden' }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/issues/3/comments?per_page=100',
      status: 403, body: { message: 'Forbidden' }
    )
    Fbe.stub(:github_graph, Fbe::Graph::Fake.new) do
      pr = { number: 3, comments: 0, user: { id: 5 }, base: { repo: { full_name: 'foo/foo' } } }
      info = Jp.comments_info(pr)
      refute_nil(info)
      assert_equal(0, info[:comments_to_code])
      assert_equal(0, info[:comments_by_author])
      assert_equal(0, info[:comments_by_reviewers])
    end
  end

  def test_resolved_graphql_error_returns_zero
    WebMock.disable_net_connect!
    rate_limit_up
    $options = Judges::Options.new({})
    $global = {}
    $loog = Loog::NULL
    stub_github('https://api.github.com/repos/foo/foo/pulls/4/comments?per_page=100', body: [])
    stub_github('https://api.github.com/repos/foo/foo/issues/4/comments?per_page=100', body: [])
    graph = Object.new
    graph.define_singleton_method(:resolved_conversations) { |_o, _r, _p| raise(GraphQL::Client::Error, 'test') }
    Fbe.stub(:github_graph, graph) do
      pr = { number: 4, user: { id: 5 }, base: { repo: { full_name: 'foo/foo' } } }
      info = Jp.comments_info(pr)
      assert_equal(0, info[:comments_resolved])
    end
  end

  def test_resolved_forbidden_returns_zero
    WebMock.disable_net_connect!
    rate_limit_up
    $options = Judges::Options.new({})
    $global = {}
    $loog = Loog::NULL
    stub_github('https://api.github.com/repos/foo/foo/pulls/5/comments?per_page=100', body: [])
    stub_github('https://api.github.com/repos/foo/foo/issues/5/comments?per_page=100', body: [])
    graph = Object.new
    graph.define_singleton_method(:resolved_conversations) do |_o, _r, _p|
      raise(Octokit::Forbidden.new(method: :get, url: 'https://api.github.com', status: 403, body: 'Forbidden'))
    end
    Fbe.stub(:github_graph, graph) do
      pr = { number: 5, user: { id: 5 }, base: { repo: { full_name: 'foo/foo' } } }
      info = Jp.comments_info(pr)
      assert_equal(0, info[:comments_resolved])
    end
  end
end
