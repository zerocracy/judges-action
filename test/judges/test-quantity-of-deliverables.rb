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
      body: { id: 42, full_name: 'foo/foo', open_issues: 0 }.to_json, headers: {
        'content-type': 'application/json'
      }
    )
    stub_request(:get, "https://api.github.com/repos/foo/foo/commits?per_page=100&since=#{time_iso8601}%2B00:00").to_return(
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
    stub_request(:get, "https://api.github.com/repos/foo/foo/issues?per_page=100&since=%3E#{test_date}").to_return(
      body: [
        {
          pull_request: {}
        }
      ].to_json,
      headers: {
        'content-type': 'application/json'
      }
    )
    fb = Factbase.new
    load_it('quantity-of-deliverables', fb)
    f = fb.query("(eq what 'quantity-of-deliverables')").each.to_a
    assert_equal(2, f.first.total_commits_pushed)
    assert_equal(20, f.first.total_hoc_committed)
    assert_equal(1, f.first.total_issues_created)
    assert_equal(1, f.first.total_pulls_submitted)
  end

  def test_processes_empty_repository
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
    stub_request(:get, "https://api.github.com/repos/foo/foo/commits?per_page=100&since=#{test_time}%2B00:00").to_return(
      status: 409,
      body: [].to_json,
      headers: {
        'content-type': 'application/json'
      }
    )
    stub_request(:get, "https://api.github.com/repos/foo/foo/issues?per_page=100&since=%3E=#{test_date}").to_return(
      body: [
        {
          pull_request: {}
        }
      ].to_json,
      headers: {
        'content-type': 'application/json'
      }
    )
    fb = Factbase.new
    load_it('quantity-of-deliverables', fb)
    f = fb.query("(eq what 'quantity-of-deliverables')").each.to_a
    assert_equal(0, f.first.total_commits_pushed)
    assert_equal(0, f.first.total_hoc_committed)
    assert_equal(1, f.first.total_issues_created)
    assert_equal(1, f.first.total_pulls_submitted)
  end
end
