# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'loog'
require 'minitest/mock'
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
    searchstub('repo:foo/foo type:issue', body: { total_count: 0, items: [] }, remaining: 0)
    assert_equal(0, Jp.qosearch('repo:foo/foo type:issue')[:total_count])
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
    searchstub('repo:foo/foo type:issue', body: { total_count: 0, items: [] }, remaining: 0)
    Jp.qosearch('repo:foo/foo type:issue')
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
          body: { rate: { remaining: left, limit: 1000 } }.to_json,
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

class TestQosSearchBudget < Minitest::Test
  SearchResult = Struct.new(:items, :total_count, keyword_init: true)
  RateLimit = Struct.new(:remaining, keyword_init: true)

  def setup
    $loog = Loog::Buffer.new
    $judge = 'test-qos-search-budget'
    Jp.qoreset
  end

  def teardown
    $loog = nil
    $judge = nil
  end

  def fake(raise_after: nil)
    octo = Object.new
    calls = [0]
    octo.define_singleton_method(:off_quota?) { false }
    octo.define_singleton_method(:search_issues) do |_q, _opts|
      calls[0] += 1
      raise(Octokit::TooManyRequests.new(body: 'rate limit exceeded')) if raise_after && calls[0] > raise_after
      SearchResult.new(items: [], total_count: 0)
    end
    octo.define_singleton_method(:rate_limit) { RateLimit.new(remaining: 5000) }
    octo.define_singleton_method(:calls_made) { calls[0] }
    octo
  end

  def test_caps_search_calls_per_window
    fake_octo = fake
    Fbe.stub(:octo, fake_octo) do
      ran = 0
      (Jp::SEARCH_WINDOW_BUDGET + 5).times do
        result = Jp.qosearch('repo:foo/bar type:issue')
        ran += 1 unless result.nil?
      end
      assert_equal(Jp::SEARCH_WINDOW_BUDGET, fake_octo.calls_made)
      assert_equal(Jp::SEARCH_WINDOW_BUDGET, ran)
      assert_match(/Approaching GitHub Search API per-minute limit/, $loog.to_s)
      assert_match(/deferring this QoS search call/, $loog.to_s)
    end
  end

  def test_resets_budget_after_window_elapses
    fake_octo = fake
    Fbe.stub(:octo, fake_octo) do
      base = Time.now
      Time.stub(:now, base) do
        Jp::SEARCH_WINDOW_BUDGET.times { Jp.qosearch('repo:foo/bar type:issue') }
      end
      assert_nil(Time.stub(:now, base + 5) { Jp.qosearch('repo:foo/bar type:issue') })
      Time.stub(:now, base + Jp::SEARCH_WINDOW_SECONDS + 1) do
        refute_nil(Jp.qosearch('repo:foo/bar type:issue'))
      end
      assert_equal(Jp::SEARCH_WINDOW_BUDGET + 1, fake_octo.calls_made)
    end
  end

  def test_stops_after_too_many_requests
    fake_octo = fake(raise_after: 0)
    Fbe.stub(:octo, fake_octo) do
      assert_nil(Jp.qosearch('repo:foo/bar type:issue'))
      assert_nil(Jp.qosearch('repo:foo/bar type:issue'))
      assert_match(/GitHub Search API quota exhausted/, $loog.to_s)
      assert_equal(1, fake_octo.calls_made)
    end
  end
end
