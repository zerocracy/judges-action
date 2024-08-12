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
    fb = Factbase.new
    load_it('quality-of-service', fb)
  end
end
