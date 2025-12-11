# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'fbe/github_graph'
require 'json'
require 'judges/options'
require 'loog'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024 Yegor Bugayenko
# License:: MIT
class TestQuantityOfDeliverables < Jp::Test
  using SmartFactbase

  def test_counts_commits
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{"rate":{"remaining":222}}', headers: { 'X-RateLimit-Remaining' => '222' } }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo',
      body: { id: 42, full_name: 'foo/foo', open_issues: 0, size: 10 }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/issues?per_page=100&since=%3E2024-07-15',
      body: [
        {
          pull_request: {}
        }
      ]
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/releases?per_page=100',
      body: [{ id: 1, draft: false, published_at: Time.parse('2024-08-01 21:00:00 UTC') }]
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/actions/runs?created=%3E2024-07-15&per_page=100',
      body: { total_count: 0, workflow_runs: [] }
    )
    fb = Factbase.new
    Fbe.stub(:github_graph, Fbe::Graph::Fake.new) do
      Time.stub(:now, Time.parse('2024-08-12 21:00:00 UTC')) do
        load_it('quantity-of-deliverables', fb)
        f = fb.query("(eq what 'quantity-of-deliverables')").each.to_a
        assert_equal(29, f.first.total_commits_pushed)
        assert_equal(1857, f.first.total_hoc_committed)
        assert_equal(1, f.first.total_issues_created)
        assert_equal(1, f.first.total_pulls_submitted)
      end
    end
  end

  def test_processes_empty_repository
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{"rate":{"remaining":222}}', headers: { 'X-RateLimit-Remaining' => '222' } }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo',
      body: { id: 42, full_name: 'foo/foo', open_issues: 0, size: 0 }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/issues?per_page=100&since=%3E2024-07-15',
      body: [
        {
          pull_request: {}
        }
      ]
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/releases?per_page=100',
      body: [{ id: 1, draft: false, published_at: Time.parse('2024-08-01 21:00:00 UTC') }]
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/actions/runs?created=%3E2024-07-15&per_page=100',
      body: { total_count: 0, workflow_runs: [] }
    )
    fb = Factbase.new
    Fbe.stub(:github_graph, Fbe::Graph::Fake.new) do
      Time.stub(:now, Time.parse('2024-08-12 21:00:00 UTC')) do
        load_it('quantity-of-deliverables', fb)
        f = fb.query("(eq what 'quantity-of-deliverables')").each.to_a
        assert_equal(0, f.first.total_commits_pushed)
        assert_equal(0, f.first.total_hoc_committed)
        assert_equal(1, f.first.total_issues_created)
        assert_equal(1, f.first.total_pulls_submitted)
      end
    end
  end

  def test_quantity_of_deliverables_total_releases_published
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{"rate":{"remaining":222}}', headers: { 'X-RateLimit-Remaining' => '222' } }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo',
      body: { id: 42, full_name: 'foo/foo', open_issues: 0, size: 100 }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/commits?per_page=100&since=2024-08-02T21:00:00%2B00:00',
      body: [
        { sha: 'bcb3cd5c2a6f3daebe1a2ab16a195a0bf2609943' },
        { sha: '0d705c564abc9e5088f00310c42b82bc9f192a3d' }
      ]
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/commits/bcb3cd5c2a6f3daebe1a2ab16a195a0bf2609943',
      body: { stats: { total: 10 } }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/commits/0d705c564abc9e5088f00310c42b82bc9f192a3d',
      body: { stats: { total: 10 } }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/issues?per_page=100&since=%3E2024-08-02',
      body: [{ pull_request: {} }]
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/releases?per_page=100',
      body: [
        { id: 1, draft: false, published_at: Time.parse('2024-08-01 21:00:00 UTC') },
        { id: 3, draft: false, published_at: Time.parse('2024-08-03 21:00:00 UTC') },
        { id: 5, draft: false, published_at: nil },
        { id: 12, draft: true, published_at: Time.parse('2024-08-05 21:00:00 UTC') },
        { id: 18, draft: false, published_at: Time.parse('2024-08-06 21:00:00 UTC') },
        { id: 25, draft: false, published_at: Time.parse('2024-08-07 21:00:00 UTC') },
        { id: 32, draft: false, published_at: Time.parse('2024-08-08 21:00:00 UTC') },
        { id: 44, draft: false, published_at: Time.parse('2024-08-09 21:00:00 UTC') },
        { id: 50, draft: false, published_at: Time.parse('2024-08-10 21:00:00 UTC') },
        { id: 55, draft: false, published_at: Time.parse('2024-08-11 21:00:00 UTC') }
      ]
    )
    stub_github('https://api.github.com/repos/foo/foo/pulls?per_page=100&state=all', body: [])
    stub_github(
      'https://api.github.com/repos/foo/foo/actions/runs?created=%3E2024-08-02&per_page=100',
      body: { total_count: 0, workflow_runs: [] }
    )
    fb = Factbase.new
    f = fb.insert
    f.what = 'pmp'
    f.area = 'scope'
    f.qod_days = 7
    Fbe.stub(:github_graph, Fbe::Graph::Fake.new) do
      Time.stub(:now, Time.parse('2024-08-09 21:00:00 UTC')) do
        load_it('quantity-of-deliverables', fb)
        f = fb.query('(eq what "quantity-of-deliverables")').each.first
        assert_equal(Time.parse('2024-08-03 00:00:00 +03:00'), f.since)
        assert_equal(Time.parse('2024-08-09 21:00:00 UTC'), f.when)
        assert_equal(7, f.total_releases_published)
      end
    end
  end

  def test_quantity_of_deliverables_total_reviews_submitted
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{"rate":{"remaining":222}}', headers: { 'X-RateLimit-Remaining' => '222' } }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo',
      body: { id: 42, full_name: 'foo/foo', open_issues: 0, size: 100 }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/commits?per_page=100&since=2024-08-02T21:00:00%2B00:00',
      body: []
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/issues?per_page=100&since=%3E2024-08-02',
      body: [{ pull_request: {} }]
    )
    stub_github('https://api.github.com/repos/foo/foo/releases?per_page=100', body: [])
    stub_github(
      'https://api.github.com/repos/foo/foo/actions/runs?created=%3E2024-08-02&per_page=100',
      body: {
        total_count: 0,
        workflow_runs: []
      }
    )
    fb = Factbase.new
    f = fb.insert
    f.what = 'pmp'
    f.area = 'scope'
    f.qod_days = 7
    Fbe.stub(:github_graph, Fbe::Graph::Fake.new) do
      Time.stub(:now, Time.parse('2024-08-09 21:00:00 UTC')) do
        load_it('quantity-of-deliverables', fb)
        f = fb.query('(eq what "quantity-of-deliverables")').each.first
        assert_equal(Time.parse('2024-08-03 00:00:00 +03:00'), f.since)
        assert_equal(Time.parse('2024-08-09 21:00:00 UTC'), f.when)
        assert_equal(4, f.total_reviews_submitted)
      end
    end
  end

  def test_quantity_of_deliverables_total_builds_ran
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{"rate":{"remaining":222}}', headers: { 'X-RateLimit-Remaining' => '222' } }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo',
      body: { id: 42, full_name: 'foo/foo', open_issues: 0, size: 100 }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/commits?per_page=100&since=2024-08-02T21:00:00%2B00:00',
      body: []
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/issues?per_page=100&since=%3E2024-08-02',
      body: [{ pull_request: {} }]
    )
    stub_github('https://api.github.com/repos/foo/foo/releases?per_page=100', body: [])
    stub_github('https://api.github.com/repos/foo/foo/pulls?per_page=100&state=all', body: [])
    stub_github(
      'https://api.github.com/repos/foo/foo/actions/runs?created=%3E2024-08-02&per_page=100',
      body: {
        total_count: 3,
        workflow_runs: [
          {
            id: 710,
            display_title: 'some title',
            run_number: 2615,
            event: 'dynamic',
            status: 'completed',
            conclusion: 'success',
            workflow_id: 141
          },
          {
            id: 708,
            display_title: 'some title',
            run_number: 2612,
            event: 'schedule',
            status: 'completed',
            conclusion: 'success',
            workflow_id: 141
          },
          {
            id: 705,
            display_title: 'some title',
            run_number: 2610,
            event: 'push',
            status: 'completed',
            conclusion: 'failure',
            workflow_id: 141
          }
        ]
      }
    )
    fb = Factbase.new
    f = fb.insert
    f.what = 'pmp'
    f.area = 'scope'
    f.qod_days = 7
    Fbe.stub(:github_graph, Fbe::Graph::Fake.new) do
      Time.stub(:now, Time.parse('2024-08-09 21:00:00 UTC')) do
        load_it('quantity-of-deliverables', fb)
        f = fb.query('(eq what "quantity-of-deliverables")').each.first
        assert_equal(Time.parse('2024-08-03 00:00:00 +03:00'), f.since)
        assert_equal(Time.parse('2024-08-09 21:00:00 UTC'), f.when)
        assert_equal(3, f.total_builds_ran)
      end
    end
  end

  def test_quantity_of_deliverables_fix_gap
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github(
      'https://api.github.com/repos/foo/foo',
      body: { id: 42, full_name: 'foo/foo', open_issues: 0, size: 100 }
    )
    stub_github('https://api.github.com/repos/foo/foo/pulls?per_page=100&state=all', body: [])
    stub_github('https://api.github.com/repos/foo/foo/releases?per_page=100', body: [])
    %w[2025-09-01 2025-09-10 2025-09-15].each do |date|
      stub_github(
        "https://api.github.com/repos/foo/foo/actions/runs?created=%3E#{date}&per_page=100",
        body: {
          total_count: 0,
          workflow_runs: []
        }
      )
      stub_github(
        "https://api.github.com/repos/foo/foo/issues?per_page=100&since=%3E#{date}",
        body: [{ pull_request: {} }]
      )
      stub_github(
        "https://api.github.com/repos/foo/foo/commits?per_page=100&since=#{date}T15:00:00%2B00:00",
        body: []
      )
    end
    fb = Factbase.new
    fb.with(
      _id: 1, what: 'quantity-of-deliverables',
      since: Time.parse('2025-09-01 15:00:00 UTC'), when: Time.parse('2025-09-10 15:00:00 UTC')
    ).with(
      _id: 2, what: 'quantity-of-deliverables',
      since: Time.parse('2025-09-15 15:00:00 UTC'), when: Time.parse('2025-09-25 15:00:00 UTC')
    )
    Fbe.stub(:github_graph, Fbe::Graph::Fake.new) do
      Time.stub(:now, Time.parse('2025-09-20 15:00:00 UTC')) do
        load_it('quantity-of-deliverables', fb)
        assert(
          fb.one?(
            what: 'quantity-of-deliverables',
            since: Time.parse('2025-09-10 15:00:00 UTC'),
            when: Time.parse('2025-09-15 15:00:00 UTC')
          )
        )
      end
    end
  end
end
