# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'judges/options'
require 'loog'
require 'webmock'
require_relative '../../lib/pull_request'
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
    WebMock.disable_net_connect!
    rate_limit_up
    $options = Judges::Options.new({})
    $global = {}
    $loog = Loog::NULL
    pr = { number: 55, head: { sha: 'bb456' }, base: { repo: { full_name: 'foo/foo' } } }
    stub_github(
      'https://api.github.com/repos/foo/foo/commits/bb456/check-runs?per_page=100',
      body: { check_runs: [{ id: 2, app: { slug: 'github-actions' } }] }
    )
    stub_github('https://api.github.com/repos/foo/foo/actions/jobs/2', body: { id: 2, run_id: 9001 })
    stub_github(
      'https://api.github.com/repos/foo/foo/actions/runs/9001',
      body: { id: 9001, event: 'pull_request', conclusion: }
    )
    Jp.fetch_workflows(pr)
  end
end
