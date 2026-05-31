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

  def test_skips_search_when_already_off_quota
    rate_limits(49)
    VCR.use_cassette('lib/qos-search/skips-search-when-already-off-quota') do
      assert_nil(Jp.qosearch('repo:foo/foo type:issue'))
    end
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
