# frozen_string_literal: true

# MIT License
#
# Copyright (c) 2024 Zerocracy
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

require 'factbase'
require 'loog'
require 'json'
require 'minitest/autorun'
require 'webmock/minitest'
require 'judges/options'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024 Yegor Bugayenko
# License:: MIT
class TestQualityOfService < Minitest::Test
  def test_runs_when_run_duration_ms_is_nil
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/user/42').to_return(
      body: { id: 42, login: 'torvalds' }.to_json, headers: {
        'content-type': 'application/json'
      }
    )
    stub_request(:get, 'https://api.github.com/repos/foo/foo').to_return(
      body: { id: 42, full_name: 'foo/foo', open_issues: 0 }.to_json, headers: {
        'content-type': 'application/json'
      }
    )
    stub_request(:get, 'https://api.github.com/repos/foo/foo/actions/runs?created=%3E2024-07-15&per_page=100').to_return(
      status: 200,
      body: {
        workflow_runs: [
          { id: 1 }
        ]
      }.to_json,
      headers: {
        'content-type': 'application/json'
      }
    )
    stub_request(:get, 'https://api.github.com/repos/foo/foo/actions/runs/1/timing').to_return(
      status: 200,
      body: {}.to_json,
      headers: {
        'content-type': 'application/json'
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
        'content-type': 'application/json'
      }
    )
    stub_request(:get, 'https://api.github.com/search/issues?per_page=100&q=repo:foo/foo%20type:issue%20closed:%3E2024-07-15').to_return(
      status: 200,
      body: {
        total_count: 1,
        items: []
      }.to_json,
      headers: {
        'content-type': 'application/json'
      }
    )
    (Date.parse('2024-07-15')..Date.parse('2024-08-12')).each do |date|
      stub_github(
        'https://api.github.com/search/issues?per_page=100&' \
        "q=repo:foo/foo%20type:issue%20created:2024-07-15..#{date}",
        body: { total_count: 0, items: [] }
      )
    end
    stub_request(:get, 'https://api.github.com/search/issues?per_page=100&q=repo:foo/foo%20type:pr%20closed:%3E2024-07-15').to_return(
      status: 200,
      body: {
        total_count: 1,
        items: []
      }.to_json,
      headers: {
        'content-type': 'application/json'
      }
    )
    stub_request(:get, 'https://api.github.com/search/issues?per_page=100&q=repo:foo/foo%20type:pr%20is:unmerged%20closed:%3E2024-07-15').to_return(
      status: 200,
      body: {
        total_count: 1,
        items: []
      }.to_json,
      headers: {
        'content-type': 'application/json'
      }
    )
    stub_github(
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:pr%20is:merged%20closed:%3E2024-07-15',
      body: {
        total_count: 1, incomplete_results: false, items: [{ id: 50, number: 12, title: 'Awesome 12' }]
      }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/12',
      body: { id: 50, number: 12, additions: 12, deletions: 5, changed_files: 3 }
    )
    fb = Factbase.new
    Time.stub(:now, Time.parse('2024-08-12 21:00:00 UTC')) do
      load_it('quality-of-service', fb)
    end
  end

  def test_quality_of_service_average_issues
    WebMock.disable_net_connect!
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
    fb = Factbase.new
    f = fb.insert
    f.what = 'pmp'
    f.area = 'quality'
    f.qos_days = 7
    f.qos_interval = 3
    Time.stub(:now, Time.parse('2024-08-09 21:00:00 UTC')) do
      load_it('quality-of-service', fb)
      f = fb.query('(eq what "quality-of-service")').each.to_a.first
      assert_equal(Time.parse('2024-08-02 21:00:00 UTC'), f.since)
      assert_equal(Time.parse('2024-08-09 21:00:00 UTC'), f.when)
      assert_in_delta(2.125, f.average_backlog_size)
    end
  end

  def test_quality_of_service_average_build_mttr
    WebMock.disable_net_connect!
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
          repository: { full_name: 'foo/foo' }
        }
      ]
    )
    fb = Factbase.new
    f = fb.insert
    f.what = 'pmp'
    f.area = 'quality'
    f.qos_days = 7
    f.qos_interval = 3
    Time.stub(:now, Time.parse('2024-08-09 21:00:00 UTC')) do
      load_it('quality-of-service', fb)
      f = fb.query('(eq what "quality-of-service")').each.to_a.first
      assert_in_delta((3900 + 4200) / 2.0, f.average_build_mttr)
    end
  end

  def test_quality_of_service_average_hocs_and_files
    WebMock.disable_net_connect!
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/repos/foo/foo/actions/runs?created=%3E2024-08-02&per_page=100',
      body: { total_count: 0, workflow_runs: [] }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/releases?per_page=100',
      body: []
    )
    stub_github(
      'https://api.github.com/search/issues?per_page=100&q=repo:foo/foo%20type:issue%20closed:%3E2024-08-02',
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
    (Date.parse('2024-08-02')..Date.parse('2024-08-09')).each do |date|
      stub_github(
        'https://api.github.com/search/issues?per_page=100&' \
        "q=repo:foo/foo%20type:issue%20created:2024-08-02..#{date}",
        body: { total_count: 0, items: [] }
      )
    end
    stub_github(
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:pr%20is:unmerged%20closed:%3E2024-08-02',
      body: {
        total_count: 1, incomplete_results: false, items: [{ id: 42, number: 10, title: 'Awesome 10' }]
      }
    )
    stub_github(
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:pr%20is:merged%20closed:%3E2024-08-02',
      body: {
        total_count: 1, incomplete_results: false,
        items: [
          { id: 50, number: 12, title: 'Awesome 12' },
          { id: 52, number: 14, title: 'Awesome 14' },
          { id: 54, number: 16, title: 'Awesome 16' },
          { id: 56, number: 18, title: 'Awesome 18' },
          { id: 58, number: 20, title: 'Awesome 20' }
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
    fb = Factbase.new
    f = fb.insert
    f.what = 'pmp'
    f.area = 'quality'
    f.qos_days = 7
    f.qos_interval = 3
    Time.stub(:now, Time.parse('2024-08-09 21:00:00 UTC')) do
      load_it('quality-of-service', fb)
      f = fb.query('(eq what "quality-of-service")').each.to_a.first
      assert_equal(Time.parse('2024-08-02 21:00:00 UTC'), f.since)
      assert_equal(Time.parse('2024-08-09 21:00:00 UTC'), f.when)
      assert_in_delta(18.4, f.average_pull_hoc_size)
      assert_in_delta(2.8, f.average_pull_files_size)
    end
  end

  private

  def stub_workflow_runs(workflow_runs)
    stub_github(
      'https://api.github.com/repos/foo/foo/actions/runs?created=%3E2024-08-02&per_page=100',
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
      'https://api.github.com/search/issues?per_page=100&q=repo:foo/foo%20type:issue%20closed:%3E2024-08-02',
      body: {
        total_count: 1, incomplete_results: false,
        items: [{ number: 42, labels: [{ name: 'bug' }] }]
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
      'q=repo:foo/foo%20type:issue%20created:2024-08-02..2024-08-02',
      body: { total_count: 0, items: [] }
    )
    stub_github(
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:issue%20created:2024-08-02..2024-08-03',
      body: { total_count: 0, items: [] }
    )
    stub_github(
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:issue%20created:2024-08-02..2024-08-04',
      body: {
        total_count: 1,
        items: [
          { number: 5, created_at: '2024-08-04 10:10 UTC', closed_at: nil }
        ]
      }
    )
    stub_github(
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:issue%20created:2024-08-02..2024-08-05',
      body: {
        total_count: 2,
        items: [
          { number: 5, created_at: '2024-08-04 10:10 UTC', closed_at: nil },
          { number: 6, created_at: '2024-08-05 10:10 UTC', closed_at: '2024-08-05 12:10 UTC' }
        ]
      }
    )
    stub_github(
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:issue%20created:2024-08-02..2024-08-06',
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
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:issue%20created:2024-08-02..2024-08-07',
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
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:issue%20created:2024-08-02..2024-08-08',
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
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:issue%20created:2024-08-02..2024-08-09',
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
      'q=repo:foo/foo%20type:pr%20is:unmerged%20closed:%3E2024-08-02',
      body: {
        total_count: 1, incomplete_results: false, items: [{ id: 42, number: 10, title: 'Awesome 10' }]
      }
    )
    stub_github(
      'https://api.github.com/search/issues?per_page=100&' \
      'q=repo:foo/foo%20type:pr%20is:merged%20closed:%3E2024-08-02',
      body: {
        total_count: 1, incomplete_results: false,
        items: [{ id: 50, number: 12, title: 'Awesome 12' }]
      }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/12',
      body: { id: 50, number: 12, additions: 12, deletions: 5, changed_files: 3 }
    )
  end
end
