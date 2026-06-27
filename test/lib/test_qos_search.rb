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

  def test_returns_search_results_while_quota_is_available
    rate_limits(1000)
    VCR.use_cassette('lib/qos-search/returns-results-while-quota-available') do
      found = Jp.qosearch('repo:foo/foo type:issue')
      assert_equal(1, found[:total_count])
      assert_equal(1, found[:items].first[:number])
    end
  end

  def test_skips_search_when_core_quota_low
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      body: { rate: { remaining: 49, limit: 1000 } }.to_json,
      headers: { 'Content-Type' => 'application/json', 'X-RateLimit-Remaining' => '49' }
    )
    assert_nil(Jp.qosearch('repo:foo/foo type:issue'))
    assert_not_requested(:get, %r{https://api\.github\.com/search/issues})
  end

  def test_skips_search_when_already_off_quota
    rate_limits(49)
    VCR.use_cassette('lib/qos-search/skips-search-when-already-off-quota') do
      assert_nil(Jp.qosearch('repo:foo/foo type:issue'))
    end
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
    rate_limit_up
    VCR.use_cassette('lib/qos-search/latches-after-zero-remaining-search-quota') do
      result = Jp.qosearch('repo:foo/foo type:issue')
      assert_equal(0, result[:total_count])
    end
  end

  def test_latches_on_too_many_requests
    rate_limits(1000, 1000)
    VCR.use_cassette('lib/qos-search/latches-on-too-many-requests') do
      assert_nil(Jp.qosearch('repo:foo/foo type:issue'))
      assert_nil(Jp.qosearch('repo:foo/foo type:pr'))
    end
  end

  def test_qoreset_clears_the_latch
    rate_limit_up
    VCR.use_cassette('lib/qos-search/qoreset-clears-latch') do
      Jp.qosearch('repo:foo/foo type:issue')
      Jp.qosearch('repo:foo/foo type:pr')
      Jp.qoreset
      result = Jp.qosearch('repo:foo/foo type:pr')
      assert_equal(2, result[:items].first[:number])
    end
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
    Jp.instance_variable_set(:@swstart, Time.now - Jp::SEARCH_WINDOW_SECONDS - 1)
    $global[:octo] = nil
    rate_limit_up
    searchstub('repo:foo/foo type:issue', body: { total_count: 1, items: [{ number: 2 }] })
    refute_nil(Jp.qosearch('repo:foo/foo type:issue'))
  end

  def test_stops_after_too_many_requests_respects_window
    rate_limit_up
    searchstub('repo:foo/foo type:issue', body: { message: 'API rate limit exceeded' }, status: 403)
    assert_nil(Jp.qosearch('repo:foo/foo type:issue'))
    assert_equal(1, Jp.instance_variable_get(:@scount))
    assert(Jp.instance_variable_get(:@offquota))
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

  def rate_limits(*remaining) # rubocop:disable Elegant/GoodMethodName
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      *remaining.map do |left|
        {
          body: { resources: { search: { remaining: left, limit: 1000 } },
                  rate: { remaining: left, limit: 1000 } }.to_json,
          headers: { 'Content-Type' => 'application/json', 'X-RateLimit-Remaining' => left.to_s }
        }
      end
    )
  end
end
