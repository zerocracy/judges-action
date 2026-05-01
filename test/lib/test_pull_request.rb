# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative '../../lib/pull_request'
require_relative '../test__helper'

class TestPullRequest < Jp::Test
  def test_fetch_workflows_skips_check_runs_with_nil_app
    WebMock.disable_net_connect!
    rate_limit_up
    pr = { base: { repo: { full_name: 'foo/foo' } }, head: { sha: 'abc123' } }
    stub_github(
      'https://api.github.com/repos/foo/foo/commits/abc123/check-runs?per_page=100',
      body: {
        total_count: 3,
        check_runs: [
          { id: 1, app: nil },
          { id: 2, app: { slug: 'other-app' } },
          { id: 3, app: { slug: 'github-actions' } }
        ]
      }
    )
    stub_github('https://api.github.com/repos/foo/foo/actions/jobs/3', body: { id: 3, run_id: 99 })
    stub_github(
      'https://api.github.com/repos/foo/foo/actions/runs/99',
      body: { id: 99, event: 'pull_request', conclusion: 'success' }
    )
    $options = Judges::Options.new({})
    $global = {}
    $loog = Loog::NULL
    result = Jp.fetch_workflows(pr)
    assert_equal({ succeeded_builds: 1, failed_builds: 0 }, result)
  end
end
