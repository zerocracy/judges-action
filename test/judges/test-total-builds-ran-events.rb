# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'
require 'judges/options'
require 'loog'
require 'uri'
require_relative '../../lib/patches/unmask_repos'
require_relative '../test__helper'

class TestTotalBuildsRanCountsNonBuilds < Jp::Test
  RUNS = [
    { id: 1, event: 'push', status: 'completed', conclusion: 'success' },
    { id: 2, event: 'pull_request', status: 'completed', conclusion: 'failure' },
    { id: 3, event: 'schedule', status: 'completed', conclusion: 'success' },
    { id: 4, event: 'dynamic', status: 'completed', conclusion: 'success' },
    { id: 5, event: 'issues', status: 'completed', conclusion: 'success' }
  ].freeze

  def test_counts_only_runs_started_by_code
    WebMock.disable_net_connect!
    rate_limit_up
    stub_request(:get, %r{\Ahttps://api\.github\.com/repos/foo/foo/actions/runs}).to_return do |req|
      q = URI.decode_www_form(URI.parse(req.uri.to_s).query.to_s).to_h
      runs = RUNS.select { |r| q['event'].nil? || r[:event] == q['event'] }
      per = Integer(q['per_page'] || 30)
      {
        status: 200,
        body: { total_count: runs.size, workflow_runs: runs.first(per) }.to_json,
        headers: { 'Content-Type' => 'application/json', 'X-RateLimit-Remaining' => '999' }
      }
    end
    fact = Object.new
    fact.define_singleton_method(:since) { Time.parse('2026-10-15 00:00:00 UTC') }
    fact.define_singleton_method(:when) { Time.parse('2026-10-22 00:00:00 UTC') }
    $judge = 'quantity-of-deliverables'
    $loog = Loog::NULL
    $global = {}
    $options = Judges::Options.new({ 'repositories' => 'foo/foo' })
    Fbe.stub(:unmask_repos, ['foo/foo']) do
      load(File.join(__dir__, '../../judges/quantity-of-deliverables/total_builds_ran.rb'))
      assert_equal(
        { total_builds_ran: 2 }, total_builds_ran(fact),
        'a scheduled job, a Pages deployment and an issue-triggered workflow are counted as builds'
      )
    end
  end
end
