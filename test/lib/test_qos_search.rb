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
    $global[:octo] = nil
  end

  def teardown
    if @rackenv.nil?
      ENV.delete('RACK_ENV')
    else
      ENV['RACK_ENV'] = @rackenv
    end
  end

  def test_returns_results_while_quota_available
    rate_limit_up
    searchstub('repo:foo/foo type:issue', body: { total_count: 1, items: [{ number: 1 }] })
    found = Jp.qosearch('repo:foo/foo type:issue')
    assert_equal(1, found[:total_count])
    assert_equal(1, found[:items].first[:number])
  end

  def test_skips_search_when_core_quota_low
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      body: { rate: { remaining: 49, limit: 1000 } }.to_json,
      headers: { 'Content-Type' => 'application/json', 'X-RateLimit-Remaining' => '49' }
    )
    assert_nil(Jp.qosearch('repo:foo/foo type:issue'))
    assert_not_requested(:get, %r{https://api\.github\.com/search/issues})
  end

  def test_skips_search_when_search_quota_zero
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      body: { rate: { remaining: 1000, limit: 1000 }, resources: { search: { remaining: 0, limit: 30 } } }.to_json,
      headers: { 'Content-Type' => 'application/json', 'X-RateLimit-Remaining' => '1000' }
    )
    assert_nil(Jp.qosearch('repo:foo/foo type:issue'))
    assert_not_requested(:get, %r{https://api\.github\.com/search/issues})
  end

  def test_skips_search_when_search_quota_missing
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      body: { rate: { remaining: 1000, limit: 1000 } }.to_json,
      headers: { 'Content-Type' => 'application/json', 'X-RateLimit-Remaining' => '1000' }
    )
    assert_nil(Jp.qosearch('repo:foo/foo type:issue'))
    assert_not_requested(:get, %r{https://api\.github\.com/search/issues})
  end

  def test_latches_after_zero_remaining_search_quota
    $global[:octo] = nil
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      body: { rate: { remaining: 1000, limit: 1000 }, resources: { search: { remaining: 30, limit: 30 } } }.to_json,
      headers: { 'Content-Type' => 'application/json', 'X-RateLimit-Remaining' => '999' }
    )
    searchstub('repo:foo/foo type:issue', body: { total_count: 58, items: [{ number: 1 }] })
    assert_equal(58, Jp.qosearch('repo:foo/foo type:issue')[:total_count])
    $global[:octo] = nil
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      body: { rate: { remaining: 1000, limit: 1000 }, resources: { search: { remaining: 0, limit: 30 } } }.to_json,
      headers: { 'Content-Type' => 'application/json', 'X-RateLimit-Remaining' => '999' }
    )
    assert_nil(Jp.qosearch('repo:foo/foo type:pr'))
    assert_not_requested(:get, /type:pr/)
  end

  def test_latches_on_too_many_requests
    rate_limit_up
    searchstub('repo:foo/foo type:issue', body: { message: 'API rate limit exceeded' }, remaining: 0, status: 403)
    assert_nil(Jp.qosearch('repo:foo/foo type:issue'))
    assert_nil(Jp.qosearch('repo:foo/foo type:pr'))
  end

  def test_qoreset_clears_the_latch
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      body: { rate: { remaining: 1000, limit: 1000 }, resources: { search: { remaining: 0, limit: 30 } } }.to_json,
      headers: { 'Content-Type' => 'application/json', 'X-RateLimit-Remaining' => '999' }
    )
    assert_nil(Jp.qosearch('repo:foo/foo type:issue'))
    Jp.qoreset
    $global[:octo] = nil
    rate_limit_up
    searchstub('repo:foo/foo type:pr', body: { total_count: 1, items: [{ number: 2 }] })
    assert_equal(2, Jp.qosearch('repo:foo/foo type:pr')[:items].first[:number])
  end

  def test_caps_search_calls_per_window
    rate_limit_up
    Jp::SEARCH_WINDOW_BUDGET.times do
      searchstub('repo:foo/foo type:issue', body: { total_count: 1, items: [{ number: 1 }] })
    end
    Jp::SEARCH_WINDOW_BUDGET.times do
      refute_nil(Jp.qosearch('repo:foo/foo type:issue'))
    end
    assert_nil(Jp.qosearch('repo:foo/foo type:issue'))
  end

  def test_resets_budget_after_window_elapses
    rate_limit_up
    Jp::SEARCH_WINDOW_BUDGET.times do
      searchstub('repo:foo/foo type:issue', body: { total_count: 1, items: [{ number: 1 }] })
    end
    Jp::SEARCH_WINDOW_BUDGET.times do
      refute_nil(Jp.qosearch('repo:foo/foo type:issue'))
    end
    assert_nil(Jp.qosearch('repo:foo/foo type:issue'))
    Jp.instance_variable_set(:@swstart, { $judge => Time.now - Jp::SEARCH_WINDOW_SECONDS - 1 })
    $global[:octo] = nil
    rate_limit_up
    searchstub('repo:foo/foo type:issue', body: { total_count: 1, items: [{ number: 2 }] })
    refute_nil(Jp.qosearch('repo:foo/foo type:issue'))
  end

  def test_stops_after_too_many_requests_respects_window
    rate_limit_up
    searchstub('repo:foo/foo type:issue', body: { message: 'API rate limit exceeded' }, status: 403)
    assert_nil(Jp.qosearch('repo:foo/foo type:issue'))
    assert_equal(1, Jp.instance_variable_get(:@scount)[$judge])
    assert(Jp.instance_variable_get(:@offquota)[$judge])
    Jp.qoreset
    $global[:octo] = nil
    rate_limit_up
    Jp::SEARCH_WINDOW_BUDGET.times do
      searchstub('repo:foo/foo type:issue', body: { total_count: 1, items: [{ number: 1 }] })
    end
    Jp::SEARCH_WINDOW_BUDGET.times do
      refute_nil(Jp.qosearch('repo:foo/foo type:issue'))
    end
    assert_nil(Jp.qosearch('repo:foo/foo type:issue'))
  end

  private

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
