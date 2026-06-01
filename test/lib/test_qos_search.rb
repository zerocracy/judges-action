# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require_relative '../../lib/qos_search'
require_relative '../test__helper'

class TestQosSearch < Jp::Test
  def setup
    @rackenv = ENV.fetch('RACK_ENV', nil)
    ENV['RACK_ENV'] = 'test'
    WebMock.reset!
    WebMock.disable_net_connect!
    $options = Judges::Options.new({})
    $global = {}
    $loog = Loog::NULL
    $judge = 'test-qos-search'
    Jp.qoreset
  end

  def teardown
    if @rackenv.nil?
      ENV.delete('RACK_ENV')
    else
      ENV['RACK_ENV'] = @rackenv
    end
  end

  def test_returns_search_results_while_quota_is_available
    ratelimits(1000, 1000, 1000)
    searchstub('repo:foo/foo type:issue', body: { total_count: 1, items: [{ number: 1 }] })
    found = Jp.qosearch('repo:foo/foo type:issue')
    assert_equal(1, found[:total_count])
    assert_equal(1, found[:items].first[:number])
  end

  def test_skips_search_when_already_off_quota
    ratelimits(49)
    assert_nil(Jp.qosearch('repo:foo/foo type:issue'))
    assert_not_requested(:get, %r{https://api\.github\.com/search/issues})
  end

  def test_latches_after_zero_remaining_search_quota
    ratelimits(1000, 1000, 0)
    searchstub('repo:foo/foo type:issue', body: { message: 'API rate limit exceeded' }, remaining: 0, status: 403)
    assert_nil(Jp.qosearch('repo:foo/foo type:issue'))
    assert_nil(Jp.qosearch('repo:foo/foo type:pr'))
    assert_not_requested(:get, 'https://api.github.com/search/issues?per_page=100&q=repo:foo/foo%20type:pr')
  end

  def test_latches_on_too_many_requests
    ratelimits(1000, 1000)
    searchstub('repo:foo/foo type:issue', body: { message: 'API rate limit exceeded' }, remaining: 0, status: 403)
    assert_nil(Jp.qosearch('repo:foo/foo type:issue'))
    assert_nil(Jp.qosearch('repo:foo/foo type:pr'))
  end

  def test_qoreset_clears_the_latch
    ratelimits(1000, 1000, 0)
    searchstub('repo:foo/foo type:issue', body: { message: 'API rate limit exceeded' }, remaining: 0, status: 403)
    assert_nil(Jp.qosearch('repo:foo/foo type:issue'))
    assert_nil(Jp.qosearch('repo:foo/foo type:pr'))
    Jp.qoreset
    ratelimits(1000, 1000, 1000)
    searchstub('repo:foo/foo type:pr', body: { total_count: 1, items: [{ number: 2 }] })
    assert_equal(2, Jp.qosearch('repo:foo/foo type:pr')[:items].first[:number])
  end

  private

  def ratelimits(*remaining)
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      *remaining.map do |left|
        {
          body: {
            resources: { search: { remaining: left, limit: 1000 } },
            rate: { remaining: left, limit: 1000 }
          }.to_json,
          headers: {
            'Content-Type' => 'application/json',
            'X-RateLimit-Remaining' => left.to_s
          }
        }
      end
    )
  end

  def searchstub(query, body:, remaining: 999, status: 200)
    stub_github(
      "https://api.github.com/search/issues?per_page=100&q=#{query.gsub(' ', '%20')}",
      body:,
      status:,
      headers: {
        'Content-Type' => 'application/json',
        'X-RateLimit-Remaining' => remaining.to_s
      }
    )
  end
end
