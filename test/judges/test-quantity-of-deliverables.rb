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
class TestQuantityOfDeliverables < Minitest::Test
  def test_counts_commits
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/user/42').to_return(
      body: { id: 42, login: 'torvalds' }.to_json, headers: {
        'content-type': 'application/json'
      }
    )
    stub_request(:get, 'https://api.github.com/repos/foo/foo').to_return(
      body: { id: 42, full_name: 'foo/foo', open_issues: 0, size: 10 }.to_json, headers: {
        'content-type': 'application/json'
      }
    )
    stub_request(:get, 'https://api.github.com/repos/foo/foo/commits?per_page=100&since=2024-07-15T21:00:00%2B00:00').to_return(
      body: [
        {
          sha: 'bcb3cd5c2a6f3daebe1a2ab16a195a0bf2609943'
        },
        {
          sha: '0d705c564abc9e5088f00310c42b82bc9f192a3d'
        }
      ].to_json,
      headers: {
        'content-type': 'application/json'
      }
    )
    stub_request(:get, 'https://api.github.com/repos/foo/foo/commits/bcb3cd5c2a6f3daebe1a2ab16a195a0bf2609943').to_return(
      body: {
        stats: {
          total: 10
        }
      }.to_json,
      headers: {
        'content-type': 'application/json'
      }
    )
    stub_request(:get, 'https://api.github.com/repos/foo/foo/commits/0d705c564abc9e5088f00310c42b82bc9f192a3d').to_return(
      body: {
        stats: {
          total: 10
        }
      }.to_json,
      headers: {
        'content-type': 'application/json'
      }
    )
    stub_request(:get, 'https://api.github.com/repos/foo/foo/issues?per_page=100&since=%3E2024-07-15').to_return(
      body: [
        {
          pull_request: {}
        }
      ].to_json,
      headers: {
        'content-type': 'application/json'
      }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/releases?per_page=100',
      body: [{ id: 1, draft: false, published_at: Time.parse('2024-08-01 21:00:00 UTC') }]
    )
    stub_github('https://api.github.com/repos/foo/foo/pulls?per_page=100&state=all', body: [])
    stub_github(
      'https://api.github.com/repos/foo/foo/actions/runs?created=%3E2024-07-15&per_page=100',
      body: { total_count: 0, workflow_runs: [] }
    )
    fb = Factbase.new
    Time.stub(:now, Time.parse('2024-08-12 21:00:00 UTC')) do
      load_it('quantity-of-deliverables', fb)
      f = fb.query("(eq what 'quantity-of-deliverables')").each.to_a
      assert_equal(2, f.first.total_commits_pushed)
      assert_equal(20, f.first.total_hoc_committed)
      assert_equal(1, f.first.total_issues_created)
      assert_equal(1, f.first.total_pulls_submitted)
    end
  end

  def test_processes_empty_repository
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/user/42').to_return(
      body: { id: 42, login: 'torvalds' }.to_json, headers: {
        'content-type': 'application/json'
      }
    )
    stub_request(:get, 'https://api.github.com/repos/foo/foo').to_return(
      body: { id: 42, full_name: 'foo/foo', open_issues: 0, size: 0 }.to_json, headers: {
        'content-type': 'application/json'
      }
    )
    stub_request(:get, 'https://api.github.com/repos/foo/foo/commits?per_page=100&since=2024-07-15T21:00:00%2B00:00').to_return(
      status: 409,
      body: [].to_json,
      headers: {
        'content-type': 'application/json'
      }
    )
    stub_request(:get, 'https://api.github.com/repos/foo/foo/issues?per_page=100&since=%3E2024-07-15').to_return(
      body: [
        {
          pull_request: {}
        }
      ].to_json,
      headers: {
        'content-type': 'application/json'
      }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/releases?per_page=100',
      body: [{ id: 1, draft: false, published_at: Time.parse('2024-08-01 21:00:00 UTC') }]
    )
    stub_github('https://api.github.com/repos/foo/foo/pulls?per_page=100&state=all', body: [])
    stub_github(
      'https://api.github.com/repos/foo/foo/actions/runs?created=%3E2024-07-15&per_page=100',
      body: { total_count: 0, workflow_runs: [] }
    )
    fb = Factbase.new
    Time.stub(:now, Time.parse('2024-08-12 21:00:00 UTC')) do
      load_it('quantity-of-deliverables', fb)
      f = fb.query("(eq what 'quantity-of-deliverables')").each.to_a
      assert_equal(0, f.first.total_commits_pushed)
      assert_equal(0, f.first.total_hoc_committed)
      assert_equal(1, f.first.total_issues_created)
      assert_equal(1, f.first.total_pulls_submitted)
    end
  end

  def test_quantity_of_deliverables_total_releases_published
    WebMock.disable_net_connect!
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
    f.qod_interval = 3
    Time.stub(:now, Time.parse('2024-08-09 21:00:00 UTC')) do
      load_it('quantity-of-deliverables', fb)
      f = fb.query('(eq what "quantity-of-deliverables")').each.to_a.first
      assert_equal(Time.parse('2024-08-03 00:00:00 +03:00'), f.since)
      assert_equal(Time.parse('2024-08-09 21:00:00 UTC'), f.when)
      assert_equal(7, f.total_releases_published)
    end
  end

  def test_quantity_of_deliverables_total_reviews_submitted
    WebMock.disable_net_connect!
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
      'https://api.github.com/repos/foo/foo/pulls?per_page=100&state=all',
      body: [
        {
          id: 2_072_543_249,
          number: 100,
          state: 'closed',
          locked: false,
          title: '#50: something title',
          user: { login: 'yegor256', id: 526_301, type: 'User' },
          body: 'Closes #50',
          created_at: Time.parse('2024-08-07 09:32:49 UTC'),
          updated_at: Time.parse('2024-08-07 21:06:23 UTC'),
          closed_at: Time.parse('2024-08-07 21:05:34 UTC'),
          merged_at: Time.parse('2024-08-07 21:05:34 UTC'),
          merge_commit_sha: '0527cc188b0495e',
          draft: false,
          head: {
            label: 'yegor256:50', ref: '50', sha: '0527cc188b049',
            user: { login: 'yegor256', id: 526_301, type: 'User' },
            repo: { id: 100_010, full_name: 'yegor256/repo' }
          },
          base: {
            label: 'zerocracy:master', ref: 'master', sha: '4643eb3c7a0ccb3c',
            user: { login: 'zerocracy', id: 24_234_201, type: 'Organization' },
            repo: { id: 99_999, full_name: 'zerocracy/repo' }
          }
        },
        {
          id: 2_072_543_245,
          number: 90,
          state: 'open',
          locked: false,
          title: '#45: something title',
          user: { login: 'yegor256', id: 526_301, type: 'User' },
          body: 'Closes #45',
          created_at: Time.parse('2024-08-02 09:32:49 UTC'),
          updated_at: Time.parse('2024-08-02 10:06:23 UTC'),
          closed_at: nil,
          merged_at: nil,
          merge_commit_sha: '0627cc188b0497e',
          draft: false,
          head: {
            label: 'yegor256:45', ref: '45', sha: '1527cc188b040',
            user: { login: 'yegor256', id: 526_301, type: 'User' },
            repo: { id: 100_010, full_name: 'yegor256/repo' }
          },
          base: {
            label: 'zerocracy:master', ref: 'master', sha: '5643eb3c7a0ccb3b',
            user: { login: 'zerocracy', id: 24_234_201, type: 'Organization' },
            repo: { id: 99_999, full_name: 'zerocracy/repo' }
          }
        },
        {
          id: 2_072_543_240,
          number: 85,
          state: 'closed',
          locked: false,
          title: '#30: something title',
          user: { login: 'yegor256', id: 526_301, type: 'User' },
          body: 'Closes #30',
          created_at: Time.parse('2024-08-01 09:32:49 UTC'),
          updated_at: Time.parse('2024-08-01 10:06:23 UTC'),
          closed_at: Time.parse('2024-08-02 10:06:23 UTC'),
          merged_at: nil,
          merge_commit_sha: '0627cc188b0497e',
          draft: false,
          head: {
            label: 'yegor256:30', ref: '30', sha: '1527cc188b085',
            user: { login: 'yegor256', id: 526_301, type: 'User' },
            repo: { id: 100_010, full_name: 'yegor256/repo' }
          },
          base: {
            label: 'zerocracy:master', ref: 'master', sha: '5643eb3c7a0ccb3b',
            user: { login: 'zerocracy', id: 24_234_201, type: 'Organization' },
            repo: { id: 99_999, full_name: 'zerocracy/repo' }
          }
        }
      ]
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/100/reviews?per_page=100',
      body: [
        {
          id: 22_449_300, body: 'Some text 1',
          user: { login: 'yegor257', id: 526_302, type: 'User' },
          state: 'CHANGES_REQUESTED', author_association: 'CONTRIBUTOR',
          submitted_at: Time.parse('2024-08-07 12:00:10 UTC')
        },
        {
          id: 22_449_250, body: 'Some text 2',
          user: { login: 'yegor257', id: 526_302, type: 'User' },
          state: 'CHANGES_REQUESTED', author_association: 'CONTRIBUTOR',
          submitted_at: Time.parse('2024-08-07 14:30:20 UTC')
        }
      ]
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/90/reviews?per_page=100',
      body: [
        {
          id: 22_449_210, body: 'Some text 1',
          user: { login: 'yegor257', id: 526_302, type: 'User' },
          state: 'CHANGES_REQUESTED', author_association: 'CONTRIBUTOR',
          submitted_at: Time.parse('2024-08-02 16:00:20 UTC')
        },
        {
          id: 22_449_215, body: 'Some text 2',
          user: { login: 'yegor257', id: 526_302, type: 'User' },
          state: 'CHANGES_REQUESTED', author_association: 'CONTRIBUTOR',
          submitted_at: Time.parse('2024-08-05 15:30:00 UTC')
        },
        {
          id: 22_449_220, body: 'Some text 3',
          user: { login: 'yegor257', id: 526_302, type: 'User' },
          state: 'CHANGES_REQUESTED', author_association: 'CONTRIBUTOR',
          submitted_at: Time.parse('2024-08-06 13:25:00 UTC')
        },
        {
          id: 22_449_225, body: 'Some text 4',
          user: { login: 'yegor257', id: 526_302, type: 'User' },
          state: 'CHANGES_REQUESTED', author_association: 'CONTRIBUTOR',
          submitted_at: Time.parse('2024-08-07 12:30:00 UTC')
        }
      ]
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/85/reviews?per_page=100',
      body: [
        {
          id: 22_449_100, body: 'Some text 1',
          user: { login: 'yegor257', id: 526_302, type: 'User' },
          state: 'CHANGES_REQUESTED', author_association: 'CONTRIBUTOR',
          submitted_at: Time.parse('2024-08-01 10:00:00 UTC')
        },
        {
          id: 22_449_110, body: 'Some text 2',
          user: { login: 'yegor257', id: 526_302, type: 'User' },
          state: 'CHANGES_REQUESTED', author_association: 'CONTRIBUTOR',
          submitted_at: Time.parse('2024-08-02 11:00:00 UTC')
        },
        {
          id: 22_449_115, body: 'Some text 3',
          user: { login: 'yegor257', id: 526_302, type: 'User' },
          state: 'CHANGES_REQUESTED', author_association: 'CONTRIBUTOR',
          submitted_at: Time.parse('2024-08-02 20:00:00 UTC')
        }
      ]
    )
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
    f.qod_interval = 3
    Time.stub(:now, Time.parse('2024-08-09 21:00:00 UTC')) do
      load_it('quantity-of-deliverables', fb)
      f = fb.query('(eq what "quantity-of-deliverables")').each.to_a.first
      assert_equal(Time.parse('2024-08-03 00:00:00 +03:00'), f.since)
      assert_equal(Time.parse('2024-08-09 21:00:00 UTC'), f.when)
      assert_equal(5, f.total_reviews_submitted)
    end
  end

  def test_quantity_of_deliverables_total_builds_ran
    WebMock.disable_net_connect!
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
    f.qod_interval = 3
    Time.stub(:now, Time.parse('2024-08-09 21:00:00 UTC')) do
      load_it('quantity-of-deliverables', fb)
      f = fb.query('(eq what "quantity-of-deliverables")').each.to_a.first
      assert_equal(Time.parse('2024-08-03 00:00:00 +03:00'), f.since)
      assert_equal(Time.parse('2024-08-09 21:00:00 UTC'), f.when)
      assert_equal(3, f.total_builds_ran)
    end
  end
end
