# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'loog'
require 'json'
require 'judges/options'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024 Yegor Bugayenko
# License:: MIT
class TestQualityOfService < Jp::Test
  using SmartFactbase

  def test_runs_when_run_duration_ms_is_nil
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{"rate":{"remaining":222}}', headers: { 'X-RateLimit-Remaining' => '222' } }
    )
    stub_request(:get, 'https://api.github.com/user/42').to_return(
      body: { id: 42, login: 'torvalds' }.to_json, headers: {
        'Content-Type': 'application/json',
        'X-RateLimit-Remaining' => '999'
      }
    )
    stub_request(:get, 'https://api.github.com/repos/foo/foo').to_return(
      body: { id: 42, full_name: 'foo/foo', open_issues: 0 }.to_json, headers: {
        'Content-Type': 'application/json',
        'X-RateLimit-Remaining' => '999'
      }
    )
    stub_request(:get, 'https://api.github.com/repos/foo/foo/actions/runs?created=2024-07-11T21:00:00Z..2024-08-12T21:00:00Z&per_page=100').to_return(
      status: 200,
      body: {
        workflow_runs: [
          { id: 1, run_started_at: Time.now - rand(10_000) }
        ]
      }.to_json,
      headers: {
        'Content-Type': 'application/json',
        'X-RateLimit-Remaining' => '999'
      }
    )
    stub_request(:get, 'https://api.github.com/repos/foo/foo/actions/runs/1/timing').to_return(
      status: 200,
      body: {}.to_json,
      headers: {
        'Content-Type': 'application/json',
        'X-RateLimit-Remaining' => '999'
      }
    )
    stub_request(:get, 'https://api.github.com/repos/foo/foo/releases?per_page=100').to_return(
      status: 200,
      body: [
        {
          id: 1,
          published_at: Time.now.to_s
        }
      ].to_json,
      headers: {
        'Content-Type': 'application/json',
        'X-RateLimit-Remaining' => '999'
      }
    )
    stub_request(
      :get,
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:issue%20closed:2024-07-11T21:00:00Z..2024-08-12T21:00:00Z'
    ).to_return(
      status: 200,
      body: {
        total_count: 1,
        items: []
      }.to_json,
      headers: {
        'Content-Type': 'application/json',
        'X-RateLimit-Remaining' => '999'
      }
    )
    (Date.parse('2024-07-15')..Date.parse('2024-08-12')).each do |date|
      stub_github(
        'https://api.github.com/search/issues?advanced_search=true&per_page=100&' \
        "q=repo:foo/foo%20type:issue%20created:*..#{date}%20(closed:%3E=#{date}%20OR%20state:open)",
        body: { total_count: 0, items: [] }
      )
    end
    stub_request(
      :get,
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:pr%20closed:2024-07-11T21:00:00Z..2024-08-12T21:00:00Z'
    ).to_return(
      status: 200,
      body: {
        total_count: 1,
        items: []
      }.to_json,
      headers: {
        'Content-Type': 'application/json'
      }
    )
    stub_request(
      :get,
      'https://api.github.com/search/issues?per_page=100&q=repo:foo/foo%20type:pr%20closed:%3E2024-07-11'
    ).to_return(
      status: 200,
      body: {
        total_count: 1,
        items: []
      }.to_json,
      headers: {
        'Content-Type': 'application/json'
      }
    )
    stub_request(
      :get,
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:pr%20is:unmerged%20closed:2024-07-11T21:00:00Z..2024-08-12T21:00:00Z'
    ).to_return(
      status: 200,
      body: {
        total_count: 1,
        items: []
      }.to_json,
      headers: {
        'Content-Type': 'application/json',
        'X-RateLimit-Remaining' => '999'
      }
    )
    stub_request(
      :get,
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:pr%20is:unmerged%20closed:%3E2024-07-11'
    ).to_return(
      status: 200,
      body: {
        total_count: 1,
        items: []
      }.to_json,
      headers: {
        'Content-Type': 'application/json',
        'X-RateLimit-Remaining' => '999'
      }
    )
    stub_github(
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:pr%20is:merged%20closed:2024-07-11T21:00:00Z..2024-08-12T21:00:00Z',
      body: {
        total_count: 1, incomplete_results: false, items: [
          {
            id: 50, number: 12, title: 'Awesome 12',
            pull_request: { merged_at: Time.parse('2024-08-23 18:30:00 UTC') }
          }
        ]
      }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/12',
      body: { id: 50, number: 12, additions: 12, deletions: 5, changed_files: 3 }
    )
    stub_github(
      'https://api.github.com/search/issues?per_page=100&q=repo:foo/foo%20type:pr%20created:%3E2024-08-02',
      body: {
        total_count: 1, incomplete_results: false,
        items: [{ id: 50, number: 12, title: 'Awesome 12', created_at: Time.parse('2024-08-20 22:00:00 UTC') }]
      }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/12/reviews?per_page=100',
      body: [{ id: 22_449_326, submitted_at: Time.parse('2024-08-21 22:00:00 UTC') }]
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/12/reviews?per_page=100',
      body: [{ id: 22_449_326, submitted_at: Time.parse('2024-07-21 22:00:00 UTC') }]
    )
    stub_github('https://api.github.com/repos/foo/foo/pulls/12/comments?per_page=100', body: [])
    stub_github(
      'https://api.github.com/search/issues?per_page=100&q=repo:foo/foo%20type:issue%20created:%3E2024-08-02',
      body: { total_count: 0, incomplete_results: false, items: [] }
    )
    stub_github(
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:issue%20created:2024-07-11T21:00:00Z..2024-08-12T21:00:00Z',
      body: { total_count: 0, incomplete_results: false, items: [] }
    )
    fb = Factbase.new
    Time.stub(:now, Time.parse('2024-08-12 21:00:00 UTC')) do
      load_it('quality-of-service', fb)
    end
  end

  def test_quality_of_service_some_release_hocs_size_and_commits_size
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{"rate":{"remaining":222}}', headers: { 'X-RateLimit-Remaining' => '222' } }
    )
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/repos/foo/foo/actions/runs?created=2024-08-02T21:00:00Z..2024-08-09T21:00:00Z&per_page=100',
      body: { total_count: 0, workflow_runs: [] }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/releases?per_page=100',
      body: [
        {
          id: 173_470,
          author: { login: 'yegor256', id: 526_301, type: 'User', site_admin: false },
          tag_name: '0.0.5', target_commitish: 'master',
          name: 'Release 5', draft: false, prerelease: false,
          created_at: Time.parse('2024-08-06 07:30:14 UTC'),
          published_at: Time.parse('2024-08-06 07:30:40 UTC'),
          assets: [], body: 'Some description', mentions_count: 4
        },
        {
          id: 173_460,
          author: { login: 'yegor256', id: 526_301, type: 'User', site_admin: false },
          tag_name: '0.0.4', target_commitish: 'master',
          name: 'Release 4', draft: false, prerelease: false,
          created_at: Time.parse('2024-08-05 21:30:14 UTC'),
          published_at: Time.parse('2024-08-05 21:30:40 UTC'),
          assets: [], body: 'Some description', mentions_count: 4
        },
        {
          id: 173_457,
          author: { login: 'yegor256', id: 526_301, type: 'User', site_admin: false },
          tag_name: '0.0.3', target_commitish: 'master',
          name: 'Release 3', draft: false, prerelease: false,
          created_at: Time.parse('2024-08-05 15:30:14 UTC'),
          published_at: Time.parse('2024-08-05 15:30:40 UTC'),
          assets: [], body: 'Some description', mentions_count: 4
        },
        {
          id: 173_450,
          author: { login: 'yegor256', id: 526_301, type: 'User', site_admin: false },
          tag_name: '0.0.2', target_commitish: 'master',
          name: 'Release 2', draft: false, prerelease: false,
          created_at: Time.parse('2024-08-04 21:30:14 UTC'),
          published_at: Time.parse('2024-08-04 21:30:40 UTC'),
          assets: [], body: 'Some description', mentions_count: 4
        },
        {
          id: 173_440,
          author: { login: 'yegor256', id: 526_301, type: 'User', site_admin: false },
          tag_name: '0.0.1', target_commitish: 'master',
          name: 'Release 1', draft: false, prerelease: false,
          created_at: Time.parse('2024-08-01 16:30:14 UTC'),
          published_at: Time.parse('2024-08-01 16:30:40 UTC'),
          assets: [], body: 'Some description', mentions_count: 4
        }
      ]
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/compare/0.0.2...0.0.3?per_page=100',
      body: {
        total_commits: 1, commits: [{ sha: 'ee04386901692ab0' }],
        files: [
          {
            sha: '9e100c7246c0cc9',
            filename: 'file.txt',
            status: 'modified',
            additions: 10,
            deletions: 10,
            changes: 20,
            patch: '@@ -24,7 +24,7 @@ text ...'
          },
          {
            sha: 'f97818271059e5455',
            filename: 'file2.txt',
            status: 'modified',
            additions: 15,
            deletions: 17,
            changes: 32,
            patch: '@@ -25,7 +25,7 @@ text ...'
          }
        ]
      }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/compare/0.0.3...0.0.4?per_page=100',
      body: {
        total_commits: 2, commits: [{ sha: 'ee04386901692ab1' }, { sha: 'ee04386901692ab2' }],
        files: [
          {
            sha: '9e100c7246c0cc9',
            filename: 'file.txt',
            status: 'modified',
            additions: 7,
            deletions: 1,
            changes: 8,
            patch: '@@ -24,7 +24,7 @@ text ...'
          },
          {
            sha: 'f97818271059e5455',
            filename: 'file2.txt',
            status: 'modified',
            additions: 6,
            deletions: 10,
            changes: 16,
            patch: '@@ -25,7 +25,7 @@ text ...'
          }
        ]
      }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/compare/0.0.4...0.0.5?per_page=100',
      body: {
        total_commits: 4,
        commits: [
          { sha: 'ea04386901692ab1' },
          { sha: 'eb04386901692ab2' },
          { sha: 'ec04386901692ab1' },
          { sha: 'ed04386901692ab2' }
        ],
        files: [
          {
            sha: '9e100c7246c0cc9',
            filename: 'file.txt',
            status: 'modified',
            additions: 50,
            deletions: 49,
            changes: 99,
            patch: '@@ -24,7 +24,7 @@ text ...'
          }
        ]
      }
    )
    stub_github(
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:issue%20closed:2024-08-02T21:00:00Z..2024-08-09T21:00:00Z',
      body: { total_count: 0, incomplete_results: false, items: [] }
    )
    stub_github(
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:pr%20closed:2024-08-02T21:00:00Z..2024-08-09T21:00:00Z',
      body: { total_count: 0, incomplete_results: false, items: [] }
    )
    stub_github(
      'https://api.github.com/search/issues?per_page=100&q=repo:foo/foo%20type:pr%20closed:%3E2024-08-02',
      body: { total_count: 0, incomplete_results: false, items: [] }
    )
    (Date.parse('2024-08-02')..Date.parse('2024-08-09')).each do |date|
      stub_github(
        'https://api.github.com/search/issues?advanced_search=true&per_page=100&' \
        "q=repo:foo/foo%20type:issue%20created:*..#{date}%20(closed:%3E=#{date}%20OR%20state:open)",
        body: { total_count: 0, items: [] }
      )
    end
    stub_github(
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:pr%20is:unmerged%20closed:2024-08-02T21:00:00Z..2024-08-09T21:00:00Z',
      body: { total_count: 0, incomplete_results: false, items: [] }
    )
    stub_github(
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:pr%20is:merged%20closed:2024-08-02T21:00:00Z..2024-08-09T21:00:00Z',
      body: { total_count: 0, incomplete_results: false, items: [] }
    )
    stub_github(
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:issue%20created:2024-08-02T21:00:00Z..2024-08-09T21:00:00Z',
      body: { total_count: 0, incomplete_results: false, items: [] }
    )
    fb = Factbase.new
    f = fb.insert
    f.what = 'pmp'
    f.area = 'quality'
    f.qos_days = 7
    f.qos_interval = 3
    Time.stub(:now, Time.parse('2024-08-09 21:00:00 UTC')) do
      load_it('quality-of-service', fb)
      f = fb.query('(eq what "quality-of-service")').each.first
      assert_equal(Time.parse('2024-08-02 21:00:00 UTC'), f.since)
      assert_equal(Time.parse('2024-08-09 21:00:00 UTC'), f.when)
      assert_equal([52, 24, 99], f['some_release_hoc_size'])
      assert_equal([1, 2, 4], f['some_release_commits_size'])
    end
  end

  def test_quality_of_service_some_build_mttr
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{"rate":{"remaining":222}}', headers: { 'X-RateLimit-Remaining' => '222' } }
    )
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, full_name: 'foo/foo' })
    stub_workflow_runs(
      [
        {
          id: 42,
          name: 'build',
          head_branch: 'master',
          head_sha: 'abc123',
          event: 'push',
          status: 'completed',
          conclusion: 'failure',
          workflow_id: 101,
          created_at: '2024-08-07T10:00:00Z',
          updated_at: '2024-08-07T10:10:00Z',
          run_started_at: '2024-08-07T10:00:00Z',
          repository: { full_name: 'foo/foo' }
        },
        {
          id: 43,
          name: 'build',
          head_branch: 'master',
          head_sha: 'abc124',
          event: 'push',
          status: 'completed',
          conclusion: 'success',
          workflow_id: 101,
          created_at: '2024-08-07T11:00:00Z',
          updated_at: '2024-08-07T11:15:00Z',
          run_started_at: '2024-08-07T11:00:00Z',
          repository: { full_name: 'foo/foo' }
        },
        {
          id: 44,
          name: 'test',
          head_branch: 'master',
          head_sha: 'abc125',
          event: 'push',
          status: 'completed',
          conclusion: 'failure',
          workflow_id: 102,
          created_at: '2024-08-08T12:00:00Z',
          updated_at: '2024-08-08T12:10:00Z',
          run_started_at: '2024-08-08T12:00:00Z',
          repository: { full_name: 'foo/foo' }
        },
        {
          id: 45,
          name: 'test',
          head_branch: 'master',
          head_sha: 'abc126',
          event: 'push',
          status: 'completed',
          conclusion: 'success',
          workflow_id: 102,
          created_at: '2024-08-08T13:00:00Z',
          updated_at: '2024-08-08T13:20:00Z',
          run_started_at: '2024-08-08T13:00:00Z',
          repository: { full_name: 'foo/foo' }
        }
      ]
    )
    stub_github(
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:issue%20closed:2024-08-02T21:00:00Z..2024-08-09T21:00:00Z',
      body: {
        total_count: 1, incomplete_results: false,
        items: [{ id: 50, number: 12, title: 'Awesome 12', created_at: Time.parse('2024-08-20 22:00:00 UTC') }]
      }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/12/reviews?per_page=100',
      body: [{ id: 22_449_326, submitted_at: Time.parse('2024-08-21 22:00:00 UTC') }]
    )
    stub_github('https://api.github.com/repos/foo/foo/pulls/12/comments?per_page=100', body: [])
    stub_github(
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:pr%20closed:2024-08-02T21:00:00Z..2024-08-09T21:00:00Z',
      body: { total_count: 0, incomplete_results: false, items: [] }
    )
    stub_github(
      'https://api.github.com/search/issues?per_page=100&q=repo:foo/foo%20type:pr%20closed:%3E2024-08-02',
      body: { total_count: 0, incomplete_results: false, items: [] }
    )
    stub_github(
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:issue%20created:2024-08-02T21:00:00Z..2024-08-09T21:00:00Z',
      body: { total_count: 0, incomplete_results: false, items: [] }
    )
    fb = Factbase.new
    f = fb.insert
    f.what = 'pmp'
    f.area = 'quality'
    f.qos_days = 7
    f.qos_interval = 3
    Time.stub(:now, Time.parse('2024-08-09 21:00:00 UTC')) do
      load_it('quality-of-service', fb)
      f = fb.query('(eq what "quality-of-service")').each.first
      assert_equal([3600, 3600], f['some_build_mttr'])
    end
  end

  def test_quality_of_service_some_build_mttr_when_failure_several_times_in_a_row
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{"rate":{"remaining":222}}', headers: { 'X-RateLimit-Remaining' => '222' } }
    )
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, full_name: 'foo/foo' })
    stub_workflow_runs(
      [
        {
          id: 42,
          name: 'build',
          head_branch: 'master',
          head_sha: 'abc123',
          event: 'push',
          status: 'completed',
          conclusion: 'success',
          workflow_id: 101,
          created_at: '2024-08-07T10:00:00Z',
          updated_at: '2024-08-07T10:10:00Z',
          run_started_at: '2024-08-07T10:00:00Z',
          repository: { full_name: 'foo/foo' }
        },
        {
          id: 43,
          name: 'build',
          head_branch: 'master',
          head_sha: 'abc124',
          event: 'push',
          status: 'completed',
          conclusion: 'failure',
          workflow_id: 101,
          created_at: '2024-08-07T11:00:00Z',
          updated_at: '2024-08-07T11:15:00Z',
          run_started_at: '2024-08-07T11:00:00Z',
          repository: { full_name: 'foo/foo' }
        },
        {
          id: 44,
          name: 'test',
          head_branch: 'master',
          head_sha: 'abc125',
          event: 'push',
          status: 'completed',
          conclusion: 'failure',
          workflow_id: 101,
          created_at: '2024-08-08T12:00:00Z',
          updated_at: '2024-08-08T12:10:00Z',
          run_started_at: '2024-08-08T12:00:00Z',
          repository: { full_name: 'foo/foo' }
        },
        {
          id: 45,
          name: 'test',
          head_branch: 'master',
          head_sha: 'abc126',
          event: 'push',
          status: 'completed',
          conclusion: 'failure',
          workflow_id: 101,
          created_at: '2024-08-08T13:00:00Z',
          updated_at: '2024-08-08T13:20:00Z',
          run_started_at: '2024-08-08T13:00:00Z',
          repository: { full_name: 'foo/foo' }
        },
        {
          id: 46,
          name: 'test',
          head_branch: 'master',
          head_sha: 'abc127',
          event: 'push',
          status: 'completed',
          conclusion: 'success',
          workflow_id: 101,
          created_at: '2024-08-08T14:00:00Z',
          updated_at: '2024-08-08T14:20:00Z',
          run_started_at: '2024-08-08T14:00:00Z',
          repository: { full_name: 'foo/foo' }
        }
      ]
    )
    stub_github(
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:issue%20closed:2024-08-02T21:00:00Z..2024-08-09T21:00:00Z',
      body: {
        total_count: 1, incomplete_results: false,
        items: [{ id: 50, number: 12, title: 'Awesome 12', created_at: Time.parse('2024-08-20 22:00:00 UTC') }]
      }
    )
    stub_github(
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:pr%20closed:2024-08-02T21:00:00Z..2024-08-09T21:00:00Z',
      body: { total_count: 0, incomplete_results: false, items: [] }
    )
    stub_github(
      'https://api.github.com/search/issues?per_page=100&q=repo:foo/foo%20type:pr%20closed:%3E2024-08-02',
      body: { total_count: 0, incomplete_results: false, items: [] }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/12/reviews?per_page=100',
      body: [{ id: 22_449_326, submitted_at: Time.parse('2024-08-21 22:00:00 UTC') }]
    )
    stub_github('https://api.github.com/repos/foo/foo/pulls/12/comments?per_page=100', body: [])
    stub_github(
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:issue%20created:2024-08-02T21:00:00Z..2024-08-09T21:00:00Z',
      body: { total_count: 0, incomplete_results: false, items: [] }
    )
    fb = Factbase.new
    f = fb.insert
    f.what = 'pmp'
    f.area = 'quality'
    f.qos_days = 7
    f.qos_interval = 3
    Time.stub(:now, Time.parse('2024-08-09 21:00:00 UTC')) do
      load_it('quality-of-service', fb)
      f = fb.query('(eq what "quality-of-service")').each.first
      assert_equal([97_200], f['some_build_mttr'])
    end
  end

  def test_quality_of_service_some_build_mttr_check_negative_mttr_values
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{"rate":{"remaining":222}}', headers: { 'X-RateLimit-Remaining' => '222' } }
    )
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, full_name: 'foo/foo' })
    stub_workflow_runs(
      [
        {
          id: 45,
          name: 'test',
          head_branch: 'master',
          head_sha: 'abc125',
          event: 'push',
          status: 'completed',
          conclusion: 'failure',
          workflow_id: 102,
          created_at: '2024-08-08T12:00:00Z',
          updated_at: '2024-08-08T12:10:00Z',
          run_started_at: '2024-08-08T12:00:00Z',
          repository: { full_name: 'foo/foo' }
        },
        {
          id: 44,
          name: 'test',
          head_branch: 'master',
          head_sha: 'abc125',
          event: 'push',
          status: 'completed',
          conclusion: 'success',
          workflow_id: 102,
          created_at: '2024-08-08T11:00:00Z',
          updated_at: '2024-08-08T11:10:00Z',
          run_started_at: '2024-08-08T11:00:00Z',
          repository: { full_name: 'foo/foo' }
        },
        {
          id: 43,
          name: 'test',
          head_branch: 'master',
          head_sha: 'abc125',
          event: 'push',
          status: 'completed',
          conclusion: 'failure',
          workflow_id: 102,
          created_at: '2024-08-08T10:00:00Z',
          updated_at: '2024-08-08T10:10:00Z',
          run_started_at: '2024-08-08T10:00:00Z',
          repository: { full_name: 'foo/foo' }
        }
      ]
    )
    stub_github(
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:issue%20closed:2024-08-02T21:00:00Z..2024-08-09T21:00:00Z',
      body: {
        total_count: 1, incomplete_results: false,
        items: [{ id: 50, number: 12, title: 'Awesome 12', created_at: Time.parse('2024-08-20 22:00:00 UTC') }]
      }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/12/reviews?per_page=100',
      body: [{ id: 22_449_326, submitted_at: Time.parse('2024-08-21 22:00:00 UTC') }]
    )
    stub_github('https://api.github.com/repos/foo/foo/pulls/12/comments?per_page=100', body: [])
    stub_github(
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:pr%20closed:2024-08-02T21:00:00Z..2024-08-09T21:00:00Z',
      body: { total_count: 0, incomplete_results: false, items: [] }
    )
    stub_github(
      'https://api.github.com/search/issues?per_page=100&q=repo:foo/foo%20type:pr%20closed:%3E2024-08-02',
      body: { total_count: 0, incomplete_results: false, items: [] }
    )
    stub_github(
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:issue%20created:2024-08-02T21:00:00Z..2024-08-09T21:00:00Z',
      body: { total_count: 0, incomplete_results: false, items: [] }
    )
    fb = Factbase.new
    f = fb.insert
    f.what = 'pmp'
    f.area = 'quality'
    f.qos_days = 7
    f.qos_interval = 3
    Time.stub(:now, Time.parse('2024-08-09 21:00:00 UTC')) do
      load_it('quality-of-service', fb)
      f = fb.query('(eq what "quality-of-service")').each.first
      assert_equal([3600], f['some_build_mttr'])
    end
  end

  def test_quality_of_service_some_hocs_and_files
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{"rate":{"remaining":222}}', headers: { 'X-RateLimit-Remaining' => '222' } }
    )
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/repos/foo/foo/actions/runs?created=2024-08-02T21:00:00Z..2024-08-09T21:00:00Z&per_page=100',
      body: { total_count: 0, workflow_runs: [] }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/releases?per_page=100',
      body: []
    )
    stub_github(
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:issue%20closed:2024-08-02T21:00:00Z..2024-08-09T21:00:00Z',
      body: {
        total_count: 1, incomplete_results: false, items: [{ number: 42, labels: [{ name: 'bug' }] }]
      }
    )
    stub_github(
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:pr%20closed:2024-08-02T21:00:00Z..2024-08-09T21:00:00Z',
      body: {
        total_count: 2, incomplete_results: false,
        items: [{ id: 42, number: 10, title: 'Awesome 10' }, { id: 43, number: 11, title: 'Awesome 11' }]
      }
    )
    stub_github(
      'https://api.github.com/search/issues?per_page=100&q=repo:foo/foo%20type:pr%20closed:%3E2024-08-02',
      body: {
        total_count: 2, incomplete_results: false,
        items: [{ id: 42, number: 10, title: 'Awesome 10' }, { id: 43, number: 11, title: 'Awesome 11' }]
      }
    )
    (Date.parse('2024-08-02')..Date.parse('2024-08-09')).each do |date|
      stub_github(
        'https://api.github.com/search/issues?advanced_search=true&per_page=100&' \
        "q=repo:foo/foo%20type:issue%20created:*..#{date}%20(closed:%3E=#{date}%20OR%20state:open)",
        body: { total_count: 0, items: [] }
      )
    end
    stub_github(
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:pr%20is:unmerged%20closed:2024-08-02T21:00:00Z..2024-08-09T21:00:00Z',
      body: {
        total_count: 1, incomplete_results: false, items: [{ id: 42, number: 10, title: 'Awesome 10' }]
      }
    )
    stub_github(
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:pr%20is:merged%20closed:2024-08-02T21:00:00Z..2024-08-09T21:00:00Z',
      body: {
        total_count: 1, incomplete_results: false,
        items: [
          {
            id: 50, number: 12, title: 'Awesome 12',
            pull_request: { merged_at: Time.parse('2024-08-23 18:30:00 UTC') }
          },
          {
            id: 52, number: 14, title: 'Awesome 14',
            pull_request: { merged_at: Time.parse('2024-08-23 18:30:00 UTC') }
          },
          {
            id: 54, number: 16, title: 'Awesome 16',
            pull_request: { merged_at: Time.parse('2024-08-23 18:30:00 UTC') }
          },
          {
            id: 56, number: 18, title: 'Awesome 18',
            pull_request: { merged_at: Time.parse('2024-08-23 18:30:00 UTC') }
          },
          {
            id: 58, number: 20, title: 'Awesome 20',
            pull_request: { merged_at: Time.parse('2024-08-23 18:30:00 UTC') }
          }
        ]
      }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/12',
      body: {
        id: 50,
        number: 12,
        additions: 10,
        deletions: 5,
        changed_files: 1
      }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/14',
      body: {
        id: 52,
        number: 14,
        additions: 0,
        deletions: 3,
        changed_files: 2
      }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/16',
      body: {
        id: 54,
        number: 16,
        additions: 8,
        deletions: 9,
        changed_files: 3
      }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/18',
      body: {
        id: 56,
        number: 18,
        additions: 30,
        deletions: 7,
        changed_files: 4
      }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/20',
      body: {
        id: 58,
        number: 20,
        additions: 20,
        deletions: 0,
        changed_files: 4
      }
    )
    stub_github(
      'https://api.github.com/search/issues?per_page=100&q=repo:foo/foo%20type:pr%20created:%3E2024-08-02',
      body: {
        total_count: 1, incomplete_results: false,
        items: [{ id: 50, number: 12, title: 'Awesome 12', created_at: Time.parse('2024-08-20 22:00:00 UTC') }]
      }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/12/reviews?per_page=100',
      body: [{ id: 22_449_326, submitted_at: Time.parse('2024-08-21 22:00:00 UTC') }]
    )
    stub_github('https://api.github.com/repos/foo/foo/pulls/12/reviews?per_page=100', body: [])
    stub_github('https://api.github.com/repos/foo/foo/pulls/14/reviews?per_page=100', body: [])
    stub_github('https://api.github.com/repos/foo/foo/pulls/16/reviews?per_page=100', body: [])
    stub_github('https://api.github.com/repos/foo/foo/pulls/18/reviews?per_page=100', body: [])
    stub_github('https://api.github.com/repos/foo/foo/pulls/20/reviews?per_page=100', body: [])
    stub_github('https://api.github.com/repos/foo/foo/pulls/12/comments?per_page=100', body: [])
    stub_github('https://api.github.com/repos/foo/foo/pulls/14/comments?per_page=100', body: [])
    stub_github('https://api.github.com/repos/foo/foo/pulls/16/comments?per_page=100', body: [])
    stub_github('https://api.github.com/repos/foo/foo/pulls/18/comments?per_page=100', body: [])
    stub_github('https://api.github.com/repos/foo/foo/pulls/20/comments?per_page=100', body: [])
    stub_github(
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:issue%20created:2024-08-02T21:00:00Z..2024-08-09T21:00:00Z',
      body: { total_count: 0, incomplete_results: false, items: [] }
    )
    fb = Factbase.new
    f = fb.insert
    f.what = 'pmp'
    f.area = 'quality'
    f.qos_days = 7
    f.qos_interval = 3
    Time.stub(:now, Time.parse('2024-08-09 21:00:00 UTC')) do
      load_it('quality-of-service', fb)
      f = fb.query('(eq what "quality-of-service")').each.first
      assert_equal(Time.parse('2024-08-02 21:00:00 UTC'), f.since)
      assert_equal(Time.parse('2024-08-09 21:00:00 UTC'), f.when)
      assert_equal([15, 3, 17, 37, 20], f['some_pull_hoc_size'])
      assert_equal([1, 2, 3, 4, 4], f['some_pull_files_size'])
    end
  end

  def test_quality_of_service_some_review_time_comments_reviewers_and_reviews
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{"rate":{"remaining":222}}', headers: { 'X-RateLimit-Remaining' => '222' } }
    )
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/repos/foo/foo/actions/runs?created=2024-08-02T21:00:00Z..2024-08-09T21:00:00Z&per_page=100',
      body: { total_count: 0, workflow_runs: [] }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/releases?per_page=100',
      body: []
    )
    stub_github(
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:issue%20closed:2024-08-02T21:00:00Z..2024-08-09T21:00:00Z',
      body: {
        total_count: 1, incomplete_results: false, items: [{ number: 42, labels: [{ name: 'bug' }] }]
      }
    )
    stub_github(
      'https://api.github.com/search/issues?per_page=100&q=repo:foo/foo%20type:pr%20closed:%3E2024-08-02',
      body: {
        total_count: 2, incomplete_results: false,
        items: [{ id: 42, number: 10, title: 'Awesome 10' }, { id: 43, number: 11, title: 'Awesome 11' }]
      }
    )
    stub_github(
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:pr%20closed:2024-08-02T21:00:00Z..2024-08-09T21:00:00Z',
      body: {
        total_count: 2, incomplete_results: false,
        items: [{ id: 42, number: 10, title: 'Awesome 10' }, { id: 43, number: 11, title: 'Awesome 11' }]
      }
    )
    (Date.parse('2024-08-02')..Date.parse('2024-08-09')).each do |date|
      stub_github(
        'https://api.github.com/search/issues?advanced_search=true&per_page=100&' \
        "q=repo:foo/foo%20type:issue%20created:*..#{date}%20(closed:%3E=#{date}%20OR%20state:open)",
        body: { total_count: 0, items: [] }
      )
    end
    stub_github(
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:pr%20is:unmerged%20closed:2024-08-02T21:00:00Z..2024-08-09T21:00:00Z',
      body: {
        total_count: 1, incomplete_results: false, items: [{ id: 42, number: 10, title: 'Awesome 10' }]
      }
    )
    stub_github(
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:pr%20is:merged%20closed:2024-08-02T21:00:00Z..2024-08-09T21:00:00Z',
      body: {
        total_count: 1, incomplete_results: false,
        items: [
          {
            id: 50, number: 12, title: 'Awesome 12',
            created_at: Time.parse('2024-08-20 22:00:00 UTC'),
            pull_request: { merged_at: Time.parse('2024-08-27 18:30:00 UTC') }
          },
          {
            id: 51, number: 14, title: 'Awesome 14',
            created_at: Time.parse('2024-08-23 12:00:00 UTC'),
            pull_request: { merged_at: Time.parse('2024-08-27 18:30:00 UTC') }
          },
          {
            id: 52, number: 16, title: 'Awesome 16',
            created_at: Time.parse('2024-08-25 12:00:00 UTC'),
            pull_request: { merged_at: Time.parse('2024-08-27 18:30:00 UTC') }
          }
        ]
      }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/12',
      body: { id: 50, number: 12, additions: 10, deletions: 5, changed_files: 1 }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/14',
      body: { id: 51, number: 14, additions: 10, deletions: 5, changed_files: 1 }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/16',
      body: { id: 52, number: 16, additions: 10, deletions: 5, changed_files: 1 }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/12/reviews?per_page=100',
      body: [
        {
          id: 22_449_328,
          body: 'Some text 3',
          user: { login: 'yegor256', id: 526_301, type: 'User' },
          state: 'CHANGES_REQUESTED',
          author_association: 'CONTRIBUTOR',
          submitted_at: nil
        },
        {
          id: 22_449_327,
          body: 'Some text 2',
          user: { login: 'yegor257', id: 526_302, type: 'User' },
          state: 'CHANGES_REQUESTED',
          author_association: 'CONTRIBUTOR',
          submitted_at: Time.parse('2024-08-22 10:00:00 UTC')
        },
        {
          id: 22_449_326,
          body: 'Some text 1',
          user: { login: 'yegor257', id: 526_302, type: 'User' },
          state: 'CHANGES_REQUESTED',
          author_association: 'CONTRIBUTOR',
          submitted_at: Time.parse('2024-08-21 22:00:00 UTC')
        }
      ]
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/14/reviews?per_page=100',
      body: [
        {
          id: 22_449_329,
          body: 'Some text 1',
          user: { login: 'yegor257', id: 526_302, type: 'User' },
          state: 'CHANGES_REQUESTED',
          author_association: 'CONTRIBUTOR',
          submitted_at: Time.parse('2024-08-23 15:30:00 UTC')
        },
        {
          id: 22_449_330,
          body: 'Some text 2',
          user: { login: 'rultor', id: 526_303, type: 'Bot' },
          state: 'CHANGES_REQUESTED',
          author_association: 'CONTRIBUTOR'
        },
        {
          id: 22_449_331,
          body: 'Some text 3',
          user: { login: 'yegor256', id: 526_301, type: 'User' },
          state: 'CHANGES_REQUESTED',
          author_association: 'CONTRIBUTOR',
          submitted_at: Time.parse('2024-08-23 17:30:00 UTC')
        },
        {
          id: 22_449_335,
          body: 'Some text 4',
          user: { login: 'yegor256', id: 526_301, type: 'User' },
          state: 'CHANGES_REQUESTED',
          author_association: 'CONTRIBUTOR',
          submitted_at: Time.parse('2024-08-23 18:30:00 UTC')
        },
        {
          id: 22_449_336,
          body: 'Some text 5',
          user: { login: 'rultor', id: 526_303, type: 'Bot' },
          state: 'CHANGES_REQUESTED',
          author_association: 'CONTRIBUTOR',
          submitted_at: Time.parse('2024-08-23 19:30:00 UTC')
        },
        {
          id: 22_449_337,
          body: 'Some text 6',
          user: { login: 'yegor257', id: 526_302, type: 'User' },
          state: 'CHANGES_REQUESTED',
          author_association: 'CONTRIBUTOR',
          submitted_at: Time.parse('2024-08-23 20:30:00 UTC')
        },
        {
          id: 22_449_338,
          body: 'Some text 7',
          user: { login: 'yegor256', id: 526_301, type: 'User' },
          state: 'CHANGES_REQUESTED',
          author_association: 'CONTRIBUTOR',
          submitted_at: Time.parse('2024-08-23 21:30:00 UTC')
        },
        {
          id: 22_449_339,
          body: 'Some text 8',
          user: { login: 'yegor256', id: 526_301, type: 'User' },
          state: 'CHANGES_REQUESTED',
          author_association: 'CONTRIBUTOR',
          submitted_at: Time.parse('2024-08-23 22:30:00 UTC')
        }
      ]
    )
    stub_github('https://api.github.com/repos/foo/foo/pulls/16/reviews?per_page=100', body: [])
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/12/comments?per_page=100',
      body: [
        {
          pull_request_review_id: 22_687_249,
          id: 17_361_949,
          diff_hunk: "@@ -427,4 +481,107 @@ def example\n",
          path: 'test/example.rb',
          commit_id: '11e3a0dd2d1',
          user: { login: 'yegor256', id: 526_301, type: 'User' },
          body: 'Some comment 1',
          created_at: Time.parse('2024-09-05 10:31:06 UTC'),
          updated_at: Time.parse('2024-09-05 10:33:04 UTC'),
          author_association: 'MEMBER'
        },
        {
          pull_request_review_id: 22_687_503,
          id: 17_361_950,
          diff_hunk: "@@ -427,4 +481,107 @@ def example\n",
          path: 'test/example.rb',
          commit_id: '11e3a0dd2d1',
          user: { login: 'Yegorov', id: 123_234_123, type: 'User' },
          body: 'Some comment 2',
          created_at: Time.parse('2024-09-05 11:40:00 UTC'),
          updated_at: Time.parse('2024-09-05 11:41:05 UTC'),
          author_association: 'CONTRIBUTOR'
        },
        {
          pull_request_review_id: 22_687_543,
          id: 17_361_955,
          diff_hunk: "@@ -427,4 +481,107 @@ def example\n",
          path: 'test/example.rb',
          commit_id: '11e3a0dd2d1',
          user: { login: 'Yegorov', id: 123_234_123, type: 'User' },
          body: 'Some comment 3',
          created_at: Time.parse('2024-09-05 15:55:07 UTC'),
          updated_at: Time.parse('2024-09-05 15:55:07 UTC'),
          author_association: 'CONTRIBUTOR'
        },
        {
          pull_request_review_id: 22_687_563,
          id: 17_361_960,
          diff_hunk: "@@ -427,4 +481,107 @@ def example\n",
          path: 'test/example.rb',
          commit_id: '11e3a0dd2d1',
          user: { login: 'Yegorov', id: 123_234_123, type: 'User' },
          body: 'Some comment 4',
          created_at: Time.parse('2024-09-05 16:40:00 UTC'),
          updated_at: Time.parse('2024-09-05 16:41:05 UTC'),
          author_association: 'CONTRIBUTOR'
        },
        {
          pull_request_review_id: 22_687_573,
          id: 17_361_970,
          diff_hunk: "@@ -427,4 +481,107 @@ def example\n",
          path: 'test/example.rb',
          commit_id: '11e3a0dd2d1',
          user: { login: 'Yegorov', id: 123_234_123, type: 'User' },
          body: 'Some comment 5',
          created_at: Time.parse('2024-09-05 17:55:07 UTC'),
          updated_at: Time.parse('2024-09-05 17:55:07 UTC'),
          author_association: 'CONTRIBUTOR'
        }
      ]
    )
    stub_github('https://api.github.com/repos/foo/foo/pulls/14/comments?per_page=100', body: [])
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/16/comments?per_page=100',
      body: [
        {
          pull_request_review_id: 22_687_505,
          id: 17_371_800,
          diff_hunk: "@@ -427,4 +481,107 @@ def example\n",
          path: 'test/example.rb',
          commit_id: '11e3a0dd2d1',
          user: { login: 'yegor256', id: 526_301, type: 'User' },
          body: 'Some comment 1',
          created_at: Time.parse('2024-09-05 10:31:06 UTC'),
          updated_at: Time.parse('2024-09-05 10:33:04 UTC'),
          author_association: 'MEMBER'
        },
        {
          pull_request_review_id: 22_687_607,
          id: 17_371_810,
          diff_hunk: "@@ -427,4 +481,107 @@ def example\n",
          path: 'test/example.rb',
          commit_id: '11e3a0dd2d1',
          user: { login: 'Yegorov', id: 123_234_123, type: 'User' },
          body: 'Some comment 2',
          created_at: Time.parse('2024-09-05 11:40:00 UTC'),
          updated_at: Time.parse('2024-09-05 11:41:05 UTC'),
          author_association: 'CONTRIBUTOR'
        },
        {
          pull_request_review_id: 22_687_617,
          id: 17_371_820,
          diff_hunk: "@@ -427,4 +481,107 @@ def example\n",
          path: 'test/example.rb',
          commit_id: '11e3a0dd2d1',
          user: { login: 'Yegorov', id: 123_234_123, type: 'User' },
          body: 'Some comment 3',
          created_at: Time.parse('2024-09-05 12:40:00 UTC'),
          updated_at: Time.parse('2024-09-05 12:41:05 UTC'),
          author_association: 'CONTRIBUTOR'
        },
        {
          pull_request_review_id: 22_687_627,
          id: 17_371_820,
          diff_hunk: "@@ -427,4 +481,107 @@ def example\n",
          path: 'test/example.rb',
          commit_id: '11e3a0dd2d1',
          user: { login: 'Yegorov', id: 123_234_123, type: 'User' },
          body: 'Some comment 4',
          created_at: Time.parse('2024-09-05 13:40:00 UTC'),
          updated_at: Time.parse('2024-09-05 13:41:05 UTC'),
          author_association: 'CONTRIBUTOR'
        },
        {
          pull_request_review_id: 22_687_637,
          id: 17_371_830,
          diff_hunk: "@@ -427,4 +481,107 @@ def example\n",
          path: 'test/example.rb',
          commit_id: '11e3a0dd2d1',
          user: { login: 'Yegorov', id: 123_234_123, type: 'User' },
          body: 'Some comment 5',
          created_at: Time.parse('2024-09-05 14:40:00 UTC'),
          updated_at: Time.parse('2024-09-05 14:41:05 UTC'),
          author_association: 'CONTRIBUTOR'
        }
      ]
    )
    stub_github(
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:issue%20created:2024-08-02T21:00:00Z..2024-08-09T21:00:00Z',
      body: { total_count: 0, incomplete_results: false, items: [] }
    )
    fb = Factbase.new
    f = fb.insert
    f.what = 'pmp'
    f.area = 'quality'
    f.qos_days = 7
    f.qos_interval = 3
    Time.stub(:now, Time.parse('2024-08-09 21:00:00 UTC')) do
      load_it('quality-of-service', fb)
      f = fb.query('(eq what "quality-of-service")').each.first
      assert_equal(Time.parse('2024-08-02 21:00:00 UTC'), f.since)
      assert_equal(Time.parse('2024-08-09 21:00:00 UTC'), f.when)
      assert_equal([505_800, 356_400], f['some_review_time'])
      assert_equal([5, 0, 5], f['some_review_size'])
      assert_equal([2, 3, 0], f['some_reviewers_per_pull'])
      assert_equal([3, 8, 0], f['some_reviews_per_pull'])
    end
  end

  def test_quality_of_service_some_triage_time
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{"rate":{"remaining":222}}', headers: { 'X-RateLimit-Remaining' => '222' } }
    )
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/repos/foo/foo/actions/runs?created=2024-08-02T21:00:00Z..2024-08-09T21:00:00Z&per_page=100',
      body: { total_count: 0, workflow_runs: [] }
    )
    stub_github('https://api.github.com/repos/foo/foo/releases?per_page=100', body: [])
    stub_github(
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:issue%20closed:2024-08-02T21:00:00Z..2024-08-09T21:00:00Z',
      body: { total_count: 0, incomplete_results: false, items: [] }
    )
    stub_github(
      'https://api.github.com/search/issues?per_page=100&q=repo:foo/foo%20type:issue%20closed:%3E2024-08-02',
      body: { total_count: 0, incomplete_results: false, items: [] }
    )
    stub_github(
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:pr%20closed:2024-08-02T21:00:00Z..2024-08-09T21:00:00Z',
      body: { total_count: 0, incomplete_results: false, items: [] }
    )
    stub_github(
      'https://api.github.com/search/issues?per_page=100&q=repo:foo/foo%20type:pr%20closed:%3E2024-08-02',
      body: { total_count: 0, incomplete_results: false, items: [] }
    )
    (Date.parse('2024-08-02')..Date.parse('2024-08-09')).each do |date|
      stub_github(
        'https://api.github.com/search/issues?advanced_search=true&per_page=100&' \
        "q=repo:foo/foo%20type:issue%20created:*..#{date}%20(closed:%3E=#{date}%20OR%20state:open)",
        body: { total_count: 0, items: [] }
      )
    end
    stub_github(
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:pr%20is:unmerged%20closed:2024-08-02T21:00:00Z..2024-08-09T21:00:00Z',
      body: { total_count: 0, incomplete_results: false, items: [] }
    )
    stub_github(
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:pr%20is:merged%20closed:2024-08-02T21:00:00Z..2024-08-09T21:00:00Z',
      body: { total_count: 0, incomplete_results: false, items: [] }
    )
    stub_github(
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:issue%20created:2024-08-02T21:00:00Z..2024-08-09T21:00:00Z',
      body: {
        total_count: 4, incomplete_results: false,
        items: [
          {
            id: 2_544_140_673,
            number: 40,
            title: 'Issue 40',
            user: { login: 'yegor256', id: 526_301, type: 'User', site_admin: false },
            labels: [
              { id: 6_937_082_637, name: 'bug', description: "Something isn't working" },
              { id: 6_937_082_658, name: 'help wanted', description: 'Extra attention is needed' }
            ],
            created_at: Time.parse('2024-08-03 12:00:00 UTC')
          },
          {
            id: 2_544_140_680,
            number: 42,
            title: 'Issue 42',
            user: { login: 'yegor256', id: 526_301, type: 'User', site_admin: false },
            labels: [
              { id: 6_937_082_651, name: 'enhancement', description: 'New feature or request' },
              { id: 6_937_082_658, name: 'help wanted', description: 'Extra attention is needed' }
            ],
            created_at: Time.parse('2024-08-04 17:00:00 UTC')
          },
          {
            id: 2_544_140_685,
            number: 45,
            title: 'Issue 45',
            user: { login: 'yegor256', id: 526_301, type: 'User', site_admin: false },
            labels: [
              { id: 6_937_082_651, name: 'enhancement', description: 'New feature or request' },
              { id: 6_937_082_658, name: 'help wanted', description: 'Extra attention is needed' }
            ],
            created_at: Time.parse('2024-08-04 18:00:00 UTC')
          },
          {
            id: 2_544_140_688,
            number: 47,
            title: 'Issue 47',
            user: { login: 'yegor256', id: 526_301, type: 'User', site_admin: false },
            labels: [
              { id: 6_937_082_637, name: 'bug', description: "Something isn't working" },
              { id: 6_937_082_658, name: 'help wanted', description: 'Extra attention is needed' }
            ],
            created_at: Time.parse('2024-08-04 19:00:00 UTC')
          }
        ]
      }
    )
    fb = Factbase.new
    fb.insert.then do |f|
      f.what = 'pmp'
      f.area = 'quality'
      f.qos_days = 7
      f.qos_interval = 3
    end
    insert_label_was_attached_fact(
      fb, where: 'gitlab', repository: 42, issue: 40, when: Time.parse('2024-08-04 11:10:00 UTC'), label: 'bug'
    )
    insert_label_was_attached_fact(
      fb, where: 'github', repository: 40, issue: 40, when: Time.parse('2024-08-04 11:10:00 UTC'), label: 'bug'
    )
    insert_label_was_attached_fact(
      fb, where: 'github', repository: 42, issue: 39, when: Time.parse('2024-08-04 11:10:00 UTC'), label: 'bug'
    )
    insert_label_was_attached_fact(
      fb, where: 'github', repository: 42, issue: 40, when: Time.parse('2024-08-04 11:10:00 UTC'), label: 'help wanted'
    )
    insert_label_was_attached_fact(
      fb, where: 'github', repository: 42, issue: 40, when: Time.parse('2024-08-04 13:10:00 UTC'), label: 'enhancement'
    )
    insert_label_was_attached_fact(
      fb, where: 'github', repository: 42, issue: 40, when: Time.parse('2024-08-04 12:30:00 UTC'), label: 'bug'
    )
    insert_label_was_attached_fact(
      fb, where: 'github', repository: 42, issue: 42, label: 'bug'
    )
    insert_label_was_attached_fact(
      fb, where: 'github', repository: 42, issue: 42, label: 'enhancement'
    )
    insert_label_was_attached_fact(
      fb, where: 'github', repository: 42, issue: 42, when: Time.parse('2024-08-04 19:00:00 UTC'), label: 'enhancement'
    )
    insert_label_was_attached_fact(
      fb, where: 'github', repository: 42, issue: 45, when: Time.parse('2024-08-06 11:00:00 UTC'), label: 'enhancement'
    )
    Time.stub(:now, Time.parse('2024-08-09 21:00:00 UTC')) do
      load_it('quality-of-service', fb)
      f = fb.query('(eq what "quality-of-service")').each.first
      assert_equal(Time.parse('2024-08-02 21:00:00 UTC'), f.since)
      assert_equal(Time.parse('2024-08-09 21:00:00 UTC'), f.when)
      assert_equal([88_200, 7_200, 147_600], f['some_triage_time'])
    end
  end

  def test_quality_of_service_fill_up_abandoned_facts
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{"rate":{"remaining":222}}', headers: { 'X-RateLimit-Remaining' => '222' } }
    )
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, full_name: 'foo/foo' })
    stub_workflow_runs(
      [{
        id: 42,
        name: 'copyrights',
        head_branch: 'master',
        head_sha: '7d34c53e6743944dbf6fc729b1066bcbb3b18443',
        event: 'push',
        status: 'completed',
        conclusion: 'success',
        workflow_id: 42,
        created_at: Time.now - rand(10_000),
        updated_at: Time.now - rand(10_000) + 100,
        run_started_at: Time.now - rand(10_000),
        repository: {
          id: 1, full_name: 'foo/foo', default_branch: 'master', private: false,
          owner: { login: 'foo', id: 526_301, site_admin: false },
          created_at: Time.now - rand(10_000),
          updated_at: Time.now - rand(10_000),
          pushed_at: Time.now - rand(10_000),
          size: 470, stargazers_count: 1, watchers_count: 1,
          language: 'Ruby', forks_count: 0, archived: false,
          open_issues_count: 6, license: { key: 'mit', name: 'MIT License' },
          visibility: 'public', forks: 0, open_issues: 6, watchers: 1
        }
      }]
    )
    stub_github('https://api.github.com/repos/foo/foo/pulls/12/comments?per_page=100', body: [])
    stub_github(
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:issue%20created:2024-08-02T21:00:00Z..2024-08-09T21:00:00Z',
      body: { total_count: 0, incomplete_results: false, items: [] }
    )
    stub_github(
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:issue%20closed:2024-08-02T21:00:00Z..2024-08-09T21:00:00Z',
      body: { total_count: 0, incomplete_results: false, items: [] }
    )
    stub_github(
      'https://api.github.com/search/issues?per_page=100&q=repo:foo/foo%20type:pr%20closed:%3E2024-07-02',
      body: {
        total_count: 2, incomplete_results: false,
        items: [{ id: 42, number: 10, title: 'Awesome 10' }, { id: 43, number: 11, title: 'Awesome 11' }]
      }
    )
    stub_github(
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:pr%20closed:2024-08-02T21:00:00Z..2024-08-09T21:00:00Z',
      body: {
        total_count: 2, incomplete_results: false,
        items: [{ id: 42, number: 10, title: 'Awesome 10' }, { id: 43, number: 11, title: 'Awesome 11' }]
      }
    )
    stub_github(
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:pr%20closed:2024-07-02T22:00:00Z..2024-07-09T22:00:00Z',
      body: {
        total_count: 2, incomplete_results: false,
        items: [{ id: 42, number: 10, title: 'Awesome 10' }, { id: 43, number: 11, title: 'Awesome 11' }]
      }
    )
    stub_github(
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:pr%20is:merged%20closed:2024-07-02T21:00:00Z..2024-07-09T21:00:00Z',
      body: { total_count: 0, incomplete_results: false, items: [] }
    )
    stub_github(
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:pr%20is:unmerged%20closed:2024-07-02T22:00:00Z..2024-07-09T22:00:00Z',
      body: { total_count: 0, incomplete_results: false, items: [] }
    )
    fb = Factbase.new
    fb.insert.then do |f|
      f.what = 'pmp'
      f.area = 'quality'
      f.qos_days = 7
      f.qos_interval = 3
    end
    fb.insert.then do |f|
      f._id = 1
      f._time = Time.parse('2024-07-09 21:00:00 UTC')
      f._version = '0.10.0/0.41.0/'
      f.what = 'quality-of-service'
      f.when = Time.parse('2024-07-09 21:00:00 UTC')
      f.since = Time.parse('2024-07-02 21:00:00 UTC')
      [].each { f.some_release_hoc_size = _1 }
      [].each { f.some_release_commits_size = _1 } # rubocop:disable Style/CombinableLoops
      [0].each { f.some_triage_time = _1 }
      [].each { f.some_release_interval = _1 }
      [1, 2, 3].each { f.some_backlog_size = _1 }
      [43_200].each { f.some_issue_lifetime = _1 }
      [90_000].each { f.some_pull_lifetime = _1 }
      [1, 2].each { f.some_build_success_rate = _1 }
      [900.0].each { f.some_build_duration = _1 }
      [3, 2, 1].each { f.some_build_mttr = _1 }
      [10_800].each { f.some_review_time = _1 }
      [].each { f.some_review_size = _1 }
      [1].each { f.some_reviewers_per_pull = _1 }
      [1].each { f.some_reviews_per_pull = _1 } # rubocop:disable Style/CombinableLoops
      [100].each { f.some_merged_pulls = _1 }
      [1].each { f.some_unmerged_pulls = _1 }
    end
    fb.insert.then do |f|
      f._id = 2
      f._time = Time.parse('2024-07-09 22:00:00 UTC')
      f._version = '0.10.0/0.41.0/'
      f.what = 'quality-of-service'
      f.when = Time.parse('2024-07-09 22:00:00 UTC')
      f.since = Time.parse('2024-07-02 22:00:00 UTC')
      [].each { f.some_release_hoc_size = _1 }
      [].each { f.some_release_commits_size = _1 } # rubocop:disable Style/CombinableLoops
      [0].each { f.some_triage_time = _1 }
      [].each { f.some_release_interval = _1 }
      [1, 2, 3].each { f.some_backlog_size = _1 }
      [43_200].each { f.some_issue_lifetime = _1 }
      [90_000].each { f.some_pull_lifetime = _1 }
      [1, 2].each { f.some_build_success_rate = _1 }
      [900.0].each { f.some_build_duration = _1 }
      [3, 2, 2].each { f.some_build_mttr = _1 }
      [10_800].each { f.some_review_time = _1 }
      [].each { f.some_review_size = _1 }
      [1].each { f.some_reviewers_per_pull = _1 }
      [1].each { f.some_reviews_per_pull = _1 } # rubocop:disable Style/CombinableLoops
      [17].each { f.some_pull_hoc_size = _1 }
      [200].each { f.some_pull_files_size = _1 }
    end
    Time.stub(:now, Time.parse('2024-07-09 21:00:00 UTC')) do
      load_it('quality-of-service', fb)
      f1, f2, * = fb.query('(eq what "quality-of-service")').each.sort_by(&:when)
      assert_equal(Time.parse('2024-07-02 21:00:00 UTC'), f1.since)
      assert_equal(Time.parse('2024-07-09 21:00:00 UTC'), f1.when)
      assert_equal([3, 2, 1], f1['some_build_mttr'])
      assert_nil(f1['some_pull_hoc_size'])
      assert_nil(f1['some_pull_files_size'])
      assert_equal([100], f1['some_merged_pulls'])
      assert_equal([1], f1['some_unmerged_pulls'])
      assert_equal(Time.parse('2024-07-02 22:00:00 UTC'), f2.since)
      assert_equal(Time.parse('2024-07-09 22:00:00 UTC'), f2.when)
      assert_equal([3, 2, 2], f2['some_build_mttr'])
      assert_equal([17], f2['some_pull_hoc_size'])
      assert_equal([200], f2['some_pull_files_size'])
      assert_equal([100], f1['some_merged_pulls'])
      assert_equal([1], f1['some_unmerged_pulls'])
    end
  end

  def test_quality_of_service_fill_up_abandoned_facts_with_exists_when_and_absent_since
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{"rate":{"remaining":222}}', headers: { 'X-RateLimit-Remaining' => '222' } }
    )
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, full_name: 'foo/foo' })
    stub_workflow_runs(
      [{
        id: 42,
        name: 'copyrights',
        head_branch: 'master',
        head_sha: '7d34c53e6743944dbf6fc729b1066bcbb3b18443',
        event: 'push',
        status: 'completed',
        conclusion: 'success',
        workflow_id: 42,
        created_at: Time.now - rand(10_000),
        updated_at: Time.now - rand(10_000) + 100,
        run_started_at: Time.now - rand(10_000),
        repository: {
          id: 1, full_name: 'foo/foo', default_branch: 'master', private: false,
          owner: { login: 'foo', id: 526_301, site_admin: false },
          created_at: Time.now - rand(10_000),
          updated_at: Time.now - rand(10_000),
          pushed_at: Time.now - rand(10_000),
          size: 470, stargazers_count: 1, watchers_count: 1,
          language: 'Ruby', forks_count: 0, archived: false,
          open_issues_count: 6, license: { key: 'mit', name: 'MIT License' },
          visibility: 'public', forks: 0, open_issues: 6, watchers: 1
        }
      }]
    )
    stub_github('https://api.github.com/repos/foo/foo/pulls/12/comments?per_page=100', body: [])
    stub_github(
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:issue%20closed:2024-08-02T21:00:00Z..2024-08-09T21:00:00Z',
      body: { total_count: 0, incomplete_results: false, items: [] }
    )
    stub_github(
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:pr%20closed:2024-08-02T21:00:00Z..2024-08-09T21:00:00Z',
      body: {
        total_count: 2, incomplete_results: false,
        items: [{ id: 42, number: 10, title: 'Awesome 10' }, { id: 43, number: 11, title: 'Awesome 11' }]
      }
    )
    stub_github(
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:issue%20created:2024-08-02T21:00:00Z..2024-08-09T21:00:00Z',
      body: { total_count: 0, incomplete_results: false, items: [] }
    )
    stub_github(
      'https://api.github.com/search/issues?per_page=100&q=repo:foo/foo%20type:pr%20closed:%3E2024-08-02',
      body: {
        total_count: 2, incomplete_results: false,
        items: [{ id: 42, number: 10, title: 'Awesome 10' }, { id: 43, number: 11, title: 'Awesome 11' }]
      }
    )
    stub_github(
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:pr%20is:unmerged%20closed:%3E2024-07-02',
      body: { total_count: 0, incomplete_results: false, items: [] }
    )
    stub_github(
      'https://api.github.com/search/issues?advanced_search=true&per_page=100&' \
      'q=repo:foo/foo%20type:issue%20created:*..2024-08-10%20(closed:%3E=2024-08-10%20OR%20state:open)',
      body: { total_count: 0, items: [] }
    )
    stub_github(
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:issue%20created:2024-07-12..2024-07-12',
      body: { total_count: 0, items: [] }
    )
    fb = Factbase.new
    fb.insert.then do |f|
      f.what = 'pmp'
      f.area = 'quality'
      f.qos_days = 7
      f.qos_interval = 3
    end
    fb.insert.then do |f|
      f._id = 1
      f._time = Time.parse('2024-08-09 21:00:00 UTC')
      f._version = '0.10.0/0.41.0/'
      f.what = 'quality-of-service'
    end
    fb.insert.then do |f|
      f._id = 2
      f._time = Time.parse('2024-08-09 21:00:00 UTC')
      f._version = '0.10.0/0.41.0/'
      f.what = 'quality-of-service'
      f.since = Time.parse('2024-08-02 21:00:00 UTC')
      f.when = Time.parse('2024-08-09 21:00:00 UTC')
    end
    Time.stub(:now, Time.parse('2024-08-10 21:00:00 UTC')) do
      load_it('quality-of-service', fb)
      fs = fb.query('(eq what "quality-of-service")').each.sort_by(&:_time)
      assert_equal(2, fs.size)
      f1, f2 = fs
      assert_nil(f1['since'])
      assert_nil(f1['when'])
      assert_equal(Time.parse('2024-08-02 21:00:00 UTC'), f2.since)
      assert_equal(Time.parse('2024-08-09 21:00:00 UTC'), f2.when)
      assert_equal([1], f2['some_build_success_rate'])
      assert_equal([900], f2['some_build_duration'])
      assert_nil(f2['some_build_mttr'])
      assert_equal([17], f2['some_pull_hoc_size'])
      assert_equal([3], f2['some_pull_files_size'])
      assert_nil(f2['some_triage_time'])
      refute_nil(f2['some_backlog_size'])
      assert_nil(f2['some_release_interval'])
      assert_equal([2], f2['some_merged_pulls'])
      assert_equal([1], f2['some_unmerged_pulls'])
      assert_nil(f2['some_issue_lifetime'])
      assert_nil(f2['some_pull_lifetime'])
      assert_equal([10_800], f2['some_review_time'])
      assert_equal([0], f2['some_review_size'])
      assert_equal([1], f2['some_reviewers_per_pull'])
      assert_equal([1], f2['some_reviews_per_pull'])
      assert_nil(f2['some_release_hoc_size'])
      assert_nil(f2['some_release_commits_size'])
    end
  end

  def test_quality_of_service_fill_up_abandoned_facts_with_exists_when_and_absent_since_and_absent_qos_days
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{"rate":{"remaining":222}}', headers: { 'X-RateLimit-Remaining' => '222' } }
    )
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:issue%20created:2024-08-02T21:00:00Z..2024-08-30T21:00:00Z',
      body: { total_count: 0, incomplete_results: false, items: [] }
    )
    stub_github(
      'https://api.github.com/search/issues?per_page=100&q=repo:foo/foo%20type:pr%20closed:%3E2024-08-02',
      body: { total_count: 0, incomplete_results: false, items: [] }
    )
    stub_workflow_runs(
      [{
        id: 42,
        name: 'copyrights',
        head_branch: 'master',
        head_sha: '7d34c53e6743944dbf6fc729b1066bcbb3b18443',
        event: 'push',
        status: 'completed',
        conclusion: 'success',
        workflow_id: 42,
        created_at: Time.now - rand(10_000),
        updated_at: Time.now - rand(10_000) + 100,
        run_started_at: Time.now - rand(10_000),
        repository: {
          id: 1, full_name: 'foo/foo', default_branch: 'master', private: false,
          owner: { login: 'foo', id: 526_301, site_admin: false },
          created_at: Time.now - rand(10_000),
          updated_at: Time.now - rand(10_000),
          pushed_at: Time.now - rand(10_000),
          size: 470, stargazers_count: 1, watchers_count: 1,
          language: 'Ruby', forks_count: 0, archived: false,
          open_issues_count: 6, license: { key: 'mit', name: 'MIT License' },
          visibility: 'public', forks: 0, open_issues: 6, watchers: 1
        }
      }]
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/actions/runs?created=2024-08-02T21:00:00Z..2024-08-30T21:00:00Z&per_page=100',
      body: { total_count: 1, workflow_runs: [] }
    )
    stub_github('https://api.github.com/repos/foo/foo/pulls/12/comments?per_page=100', body: [])
    (Date.parse('2024-08-10')..Date.parse('2024-09-01')).each do |date|
      stub_github(
        'https://api.github.com/search/issues?advanced_search=true&per_page=100&' \
        "q=repo:foo/foo%20type:issue%20created:*..#{date}%20(closed:%3E=#{date}%20OR%20state:open)",
        body: { total_count: 0, items: [] }
      )
    end
    fb = Factbase.new
    fb.insert.then do |f|
      f.what = 'pmp'
      f.area = 'quality'
      f.qos_interval = 3
    end
    fb.insert.then do |f|
      f._id = 1
      f._time = Time.parse('2024-08-30 21:00:00 UTC')
      f._version = '0.10.0/0.41.0/'
      f.what = 'quality-of-service'
      f.since = Time.parse('2024-08-02 21:00:00 UTC')
      f.when = Time.parse('2024-08-30 21:00:00 UTC')
    end
    Time.stub(:now, Time.parse('2024-09-01 21:00:00 UTC')) do
      load_it('quality-of-service', fb)
      f = fb.query('(eq what "quality-of-service")').each.first
      assert_equal(Time.parse('2024-08-02 21:00:00 UTC'), f.since)
      assert_equal(Time.parse('2024-08-30 21:00:00 UTC'), f.when)
      assert_nil(f['some_release_commits_size'])
    end
  end

  def test_quality_of_service_some_backlog_size
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{"rate":{"remaining":222}}', headers: { 'X-RateLimit-Remaining' => '222' } }
    )
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/search/issues?advanced_search=true&per_page=100&' \
      'q=repo:foo/foo%20type:issue%20created:*..2025-08-22%20(closed:%3E=2025-08-22%20OR%20state:open)',
      body: {
        total_count: 1,
        items: [
          { number: 5, created_at: Time.parse('2025-08-10 10:10 UTC'), closed_at: nil }
        ]
      }
    )
    stub_github(
      'https://api.github.com/search/issues?advanced_search=true&per_page=100&' \
      'q=repo:foo/foo%20type:issue%20created:*..2025-08-23%20(closed:%3E=2025-08-23%20OR%20state:open)',
      body: {
        total_count: 2,
        items: [
          { number: 5, created_at: Time.parse('2025-08-10 10:10 UTC'), closed_at: nil },
          { number: 7, created_at: Time.parse('2025-08-23 10:10 UTC'), closed_at: Time.parse('2025-08-25 12:10 UTC') }
        ]
      }
    )
    stub_github(
      'https://api.github.com/search/issues?advanced_search=true&per_page=100&' \
      'q=repo:foo/foo%20type:issue%20created:*..2025-08-24%20(closed:%3E=2025-08-24%20OR%20state:open)',
      body: {
        total_count: 2,
        items: [
          { number: 5, created_at: Time.parse('2025-08-10 10:10 UTC'), closed_at: nil },
          { number: 7, created_at: Time.parse('2025-08-23 10:10 UTC'), closed_at: Time.parse('2025-08-25 12:10 UTC') }
        ]
      }
    )
    stub_github(
      'https://api.github.com/search/issues?advanced_search=true&per_page=100&' \
      'q=repo:foo/foo%20type:issue%20created:*..2025-08-25%20(closed:%3E=2025-08-25%20OR%20state:open)',
      body: {
        total_count: 2,
        items: [
          { number: 5, created_at: Time.parse('2025-08-10 10:10 UTC'), closed_at: nil },
          { number: 7, created_at: Time.parse('2025-08-23 10:10 UTC'), closed_at: Time.parse('2025-08-25 12:10 UTC') }
        ]
      }
    )
    stub_github(
      'https://api.github.com/search/issues?advanced_search=true&per_page=100&' \
      'q=repo:foo/foo%20type:issue%20created:*..2025-08-26%20(closed:%3E=2025-08-26%20OR%20state:open)',
      body: {
        total_count: 2,
        items: [
          { number: 5, created_at: Time.parse('2025-08-10 10:10 UTC'), closed_at: nil },
          { number: 8, created_at: Time.parse('2025-08-26 10:10 UTC'), closed_at: Time.parse('2025-08-26 12:10 UTC') }
        ]
      }
    )
    stub_github(
      'https://api.github.com/search/issues?advanced_search=true&per_page=100&' \
      'q=repo:foo/foo%20type:issue%20created:*..2025-08-27%20(closed:%3E=2025-08-27%20OR%20state:open)',
      body: {
        total_count: 1,
        items: [
          { number: 5, created_at: Time.parse('2025-08-10 10:10 UTC'), closed_at: nil }
        ]
      }
    )
    stub_github(
      'https://api.github.com/search/issues?advanced_search=true&per_page=100&' \
      'q=repo:foo/foo%20type:issue%20created:*..2025-08-28%20(closed:%3E=2025-08-28%20OR%20state:open)',
      body: {
        total_count: 1,
        items: [
          { number: 5, created_at: Time.parse('2025-08-10 10:10 UTC'), closed_at: nil }
        ]
      }
    )
    stub_github('https://api.github.com/repos/foo/foo/releases?per_page=100', body: [])
    stub_github(
      'https://api.github.com/repos/foo/foo/actions/runs?created=2025-08-21T21:00:00Z..2025-08-28T21:00:00Z&per_page=100',
      body: { total_count: 0, workflow_runs: [] }
    )
    stub_github(
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:issue%20closed:2025-08-21T21:00:00Z..2025-08-28T21:00:00Z',
      body: { total_count: 0, incomplete_results: false, items: [] }
    )
    stub_github(
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:pr%20closed:2025-08-21T21:00:00Z..2025-08-28T21:00:00Z',
      body: { total_count: 0, incomplete_results: false, items: [] }
    )
    stub_github(
      'https://api.github.com/search/issues?per_page=100&q=repo:foo/foo%20type:pr%20closed:%3E2025-08-21',
      body: { total_count: 0, incomplete_results: false, items: [] }
    )
    stub_github(
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:pr%20is:merged%20closed:2025-08-21T21:00:00Z..2025-08-28T21:00:00Z',
      body: { total_count: 0, incomplete_results: false, items: [] }
    )
    stub_github(
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:pr%20is:unmerged%20closed:2025-08-21T21:00:00Z..2025-08-28T21:00:00Z',
      body: { total_count: 0, incomplete_results: false, items: [] }
    )
    stub_github(
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:issue%20created:2025-08-21T21:00:00Z..2025-08-28T21:00:00Z',
      body: { total_count: 0, incomplete_results: false, items: [] }
    )
    fb = Factbase.new
    fb.insert.then do |f|
      f.what = 'pmp'
      f.area = 'quality'
      f.qos_days = 7
      f.qos_interval = 3
    end
    Time.stub(:now, Time.parse('2025-08-28 21:00:00 UTC')) do
      load_it('quality-of-service', fb)
      f = fb.query('(eq what "quality-of-service")').each.first
      assert_equal([1, 2, 2, 2, 2, 1, 1], f['some_backlog_size'])
    end
  end

  def test_quality_of_service_fix_gap
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, full_name: 'foo/foo' })
    stub_github('https://api.github.com/repos/foo/foo/releases?per_page=100', body: [])
    %w[
      2025-09-01T15:00:00Z..2025-09-10T15:00:00Z
      2025-09-15T15:00:00Z..2025-09-25T15:00:00Z
      2025-09-10T15:00:00Z..2025-09-15T15:00:00Z
    ].each do |period|
      stub_github(
        'https://api.github.com/search/issues?per_page=100&' \
        "q=repo:foo/foo%20type:issue%20closed:#{period}",
        body: { total_count: 0, incomplete_results: false, items: [] }
      )
      stub_github(
        'https://api.github.com/search/issues?per_page=100&' \
        "q=repo:foo/foo%20type:issue%20created:#{period}",
        body: { total_count: 0, incomplete_results: false, items: [] }
      )
      stub_github(
        'https://api.github.com/search/issues?per_page=100&' \
        "q=repo:foo/foo%20type:pr%20closed:#{period}",
        body: { total_count: 0, incomplete_results: false, items: [] }
      )
      stub_github(
        'https://api.github.com/search/issues?per_page=100&' \
        "q=repo:foo/foo%20type:pr%20is:merged%20closed:#{period}",
        body: { total_count: 0, incomplete_results: false, items: [] }
      )
      stub_github(
        'https://api.github.com/search/issues?per_page=100&' \
        "q=repo:foo/foo%20type:pr%20is:unmerged%20closed:#{period}",
        body: { total_count: 0, incomplete_results: false, items: [] }
      )
      stub_github(
        "https://api.github.com/repos/foo/foo/actions/runs?created=#{period}&per_page=100",
        body: { total_count: 0, workflow_runs: [] }
      )
    end
    %w[
      2025-09-04 2025-09-05 2025-09-06 2025-09-07 2025-09-08 2025-09-09 2025-09-10
      2025-09-19 2025-09-20 2025-09-21 2025-09-22 2025-09-23 2025-09-24 2025-09-25
      2025-09-11 2025-09-12 2025-09-13 2025-09-14 2025-09-15
    ].each do |date|
      stub_github(
        'https://api.github.com/search/issues?advanced_search=true&per_page=100&' \
        "q=repo:foo/foo%20type:issue%20created:*..#{date}%20(closed:%3E=#{date}%20OR%20state:open)",
        body: { total_count: 0, items: [] }
      )
    end
    fb = Factbase.new
    fb.with(
      _id: 1, what: 'quality-of-service',
      since: Time.parse('2025-09-01 15:00:00 UTC'), when: Time.parse('2025-09-10 15:00:00 UTC')
    ).with(
      _id: 2, what: 'quality-of-service',
      since: Time.parse('2025-09-15 15:00:00 UTC'), when: Time.parse('2025-09-25 15:00:00 UTC')
    )
    Time.stub(:now, Time.parse('2025-09-22 15:00:00 UTC')) do
      load_it('quality-of-service', fb)
      assert(
        fb.one?(
          what: 'quality-of-service',
          since: Time.parse('2025-09-10 15:00:00 UTC'),
          when: Time.parse('2025-09-15 15:00:00 UTC')
        )
      )
    end
  end

  private

  def stub_workflow_runs(workflow_runs)
    stub_github(
      'https://api.github.com/repos/foo/foo/actions/runs?created=2024-08-02T21:00:00Z..2024-08-09T21:00:00Z&per_page=100',
      body: {
        total_count: 1,
        workflow_runs:
      }
    )
    workflow_runs.each do |run|
      stub_github(
        "https://api.github.com/repos/foo/foo/actions/runs/#{run[:id]}/timing",
        body: { run_duration_ms: 900_000 }
      )
    end
    stub_github(
      'https://api.github.com/repos/foo/foo/releases?per_page=100',
      body: [{
        node_id: 'RE_kwDOL6GCO84J7Cen', tag_name: '0.19.0', target_commitish: 'master',
        name: 'just a fake name', draft: false, prerelease: false,
        created_at: Time.now - rand(10_000), published_at: Time.now - rand(10_000), assets: []
      }]
    )
    stub_github(
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:issue%20closed:2024-08-02T21:00:00Z..2024-08-30T21:00:00Z',
      body: {
        total_count: 1, incomplete_results: false,
        items: [{ number: 42, labels: [{ name: 'bug' }] }]
      }
    )
    stub_github(
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:pr%20closed:2024-08-02T21:00:00Z..2024-08-30T21:00:00Z',
      body: {
        total_count: 2, incomplete_results: false,
        items: [{ id: 42, number: 10, title: 'Awesome 10' }, { id: 43, number: 11, title: 'Awesome 11' }]
      }
    )
    stub_github(
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:issue%20created:2024-08-02..2024-08-02',
      body: { total_count: 0, items: [] }
    )
    stub_github(
      'https://api.github.com/search/issues?advanced_search=true&per_page=100&' \
      'q=repo:foo/foo%20type:issue%20created:*..2024-08-03%20(closed:%3E=2024-08-03%20OR%20state:open)',
      body: { total_count: 0, items: [] }
    )
    stub_github(
      'https://api.github.com/search/issues?advanced_search=true&per_page=100&' \
      'q=repo:foo/foo%20type:issue%20created:*..2024-08-04%20(closed:%3E=2024-08-04%20OR%20state:open)',
      body: {
        total_count: 1,
        items: [
          { number: 5, created_at: '2024-08-04 10:10 UTC', closed_at: nil }
        ]
      }
    )
    stub_github(
      'https://api.github.com/search/issues?advanced_search=true&per_page=100&' \
      'q=repo:foo/foo%20type:issue%20created:*..2024-08-05%20(closed:%3E=2024-08-05%20OR%20state:open)',
      body: {
        total_count: 2,
        items: [
          { number: 5, created_at: '2024-08-04 10:10 UTC', closed_at: nil },
          { number: 6, created_at: '2024-08-05 10:10 UTC', closed_at: '2024-08-05 12:10 UTC' }
        ]
      }
    )
    stub_github(
      'https://api.github.com/search/issues?advanced_search=true&per_page=100&' \
      'q=repo:foo/foo%20type:issue%20created:*..2024-08-06%20(closed:%3E=2024-08-06%20OR%20state:open)',
      body: {
        total_count: 3,
        items: [
          { number: 5, created_at: '2024-08-04 10:10 UTC', closed_at: nil },
          { number: 6, created_at: '2024-08-05 10:10 UTC', closed_at: '2024-08-05 12:10 UTC' },
          { number: 7, created_at: '2024-08-06 10:10 UTC', closed_at: '2024-08-08 12:10 UTC' },
          { number: 8, created_at: '2024-08-06 10:10 UTC', closed_at: '2024-08-09 12:10 UTC' }
        ]
      }
    )
    stub_github(
      'https://api.github.com/search/issues?advanced_search=true&per_page=100&' \
      'q=repo:foo/foo%20type:issue%20created:*..2024-08-07%20(closed:%3E=2024-08-07%20OR%20state:open)',
      body: {
        total_count: 4,
        items: [
          { number: 5, created_at: '2024-08-04 10:10 UTC', closed_at: nil },
          { number: 6, created_at: '2024-08-05 10:10 UTC', closed_at: '2024-08-05 12:10 UTC' },
          { number: 7, created_at: '2024-08-06 10:10 UTC', closed_at: '2024-08-08 12:10 UTC' },
          { number: 8, created_at: '2024-08-06 10:10 UTC', closed_at: '2024-08-09 12:10 UTC' },
          { number: 9, created_at: '2024-08-07 10:10 UTC', closed_at: '2024-08-09 12:10 UTC' }
        ]
      }
    )
    stub_github(
      'https://api.github.com/search/issues?advanced_search=true&per_page=100&' \
      'q=repo:foo/foo%20type:issue%20created:*..2024-08-08%20(closed:%3E=2024-08-08%20OR%20state:open)',
      body: {
        total_count: 4,
        items: [
          { number: 5, created_at: '2024-08-04 10:10 UTC', closed_at: nil },
          { number: 6, created_at: '2024-08-05 10:10 UTC', closed_at: '2024-08-05 12:10 UTC' },
          { number: 7, created_at: '2024-08-06 10:10 UTC', closed_at: '2024-08-08 12:10 UTC' },
          { number: 8, created_at: '2024-08-06 10:10 UTC', closed_at: '2024-08-09 12:10 UTC' },
          { number: 9, created_at: '2024-08-07 10:10 UTC', closed_at: '2024-08-09 12:10 UTC' }
        ]
      }
    )
    stub_github(
      'https://api.github.com/search/issues?advanced_search=true&per_page=100&' \
      'q=repo:foo/foo%20type:issue%20created:*..2024-08-09%20(closed:%3E=2024-08-09%20OR%20state:open)',
      body: {
        total_count: 3,
        items: [
          { number: 5, created_at: '2024-08-04 10:10 UTC', closed_at: nil },
          { number: 6, created_at: '2024-08-05 10:10 UTC', closed_at: '2024-08-05 12:10 UTC' },
          { number: 7, created_at: '2024-08-06 10:10 UTC', closed_at: '2024-08-08 12:10 UTC' },
          { number: 8, created_at: '2024-08-06 10:10 UTC', closed_at: '2024-08-09 12:10 UTC' },
          { number: 9, created_at: '2024-08-07 10:10 UTC', closed_at: '2024-08-09 12:10 UTC' }
        ]
      }
    )
    stub_github(
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:pr%20is:unmerged%20closed:2024-08-02T21:00:00Z..2024-08-09T21:00:00Z',
      body: {
        total_count: 1, incomplete_results: false, items: [{ id: 42, number: 10, title: 'Awesome 10' }]
      }
    )
    stub_github(
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:pr%20is:unmerged%20closed:2024-08-02T21:00:00Z..2024-08-30T21:00:00Z',
      body: {
        total_count: 1, incomplete_results: false, items: [{ id: 42, number: 10, title: 'Awesome 10' }]
      }
    )
    stub_github(
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:pr%20is:merged%20closed:2024-08-02T21:00:00Z..2024-08-09T21:00:00Z',
      body: {
        total_count: 1, incomplete_results: false,
        items: [
          {
            id: 50, number: 12, title: 'Awesome 12',
            pull_request: { merged_at: Time.parse('2024-08-23 18:30:00 UTC') }
          }
        ]
      }
    )
    stub_github(
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:pr%20is:merged%20closed:2024-08-02T21:00:00Z..2024-08-30T21:00:00Z',
      body: {
        total_count: 1, incomplete_results: false,
        items: [
          {
            id: 50, number: 12, title: 'Awesome 12',
            pull_request: { merged_at: Time.parse('2024-08-23 18:30:00 UTC') }
          }
        ]
      }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/12',
      body: { id: 50, number: 12, additions: 12, deletions: 5, changed_files: 3 }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/12/reviews?per_page=100',
      body: [
        {
          id: 22_449_329, body: 'Some text 1', state: 'CHANGES_REQUESTED',
          author_association: 'CONTRIBUTOR', submitted_at: Time.parse('2024-08-23 15:30:00 UTC')
        }
      ]
    )
  end

  def insert_label_was_attached_fact(fb, **kwargs)
    fb.insert.then do |f|
      f.what = 'label-was-attached'
      %i[where repository issue when label].each do |prop|
        f.send(:"#{prop}=", kwargs[prop]) unless kwargs[prop].nil?
      end
    end
  end
end
