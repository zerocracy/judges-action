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
end
