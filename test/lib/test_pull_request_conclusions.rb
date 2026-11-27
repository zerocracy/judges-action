# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'judges/options'
require 'loog'
require_relative '../../lib/pull_request'
require_relative '../fake_github'
require_relative '../test__helper'

class TestPullRequestConclusions < Jp::Test
  def test_counts_a_cancelled_run_as_a_failure
    assert_equal({ succeeded_builds: 0, failed_builds: 1 }, counted('cancelled'))
  end

  def test_counts_a_run_that_timed_out_as_a_failure
    assert_equal({ succeeded_builds: 0, failed_builds: 1 }, counted('timed_out'))
  end

  def test_counts_a_skipped_run_as_nothing
    assert_equal({ succeeded_builds: 0, failed_builds: 0 }, counted('skipped'))
  end

  private

  def counted(conclusion)
    $options = Judges::Options.new({})
    $global = {}
    $loog = Loog::NULL
    pr = { number: 55, head: { sha: 'bb456' }, base: { repo: { full_name: 'foo/foo' } } }
    Jp::FakeGithub.new(
      'GET /rate_limit' => {
        resources: { search: { remaining: 30, limit: 30 } }, rate: { remaining: 1000, limit: 1000 }
      },
      'GET /repos/foo/foo/commits/bb456/check-runs?per_page=100' => {
        check_runs: [{ id: 2, app: { slug: 'github-actions' } }]
      },
      'GET /repos/foo/foo/actions/jobs/2' => { id: 2, run_id: 9001 },
      'GET /repos/foo/foo/actions/runs/9001' => { id: 9001, event: 'pull_request', conclusion: }
    ).run { Jp.fetch_workflows(pr) }
  end
end
