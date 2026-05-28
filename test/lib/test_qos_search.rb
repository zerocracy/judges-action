# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'loog'
require 'minitest/mock'
require_relative '../../lib/qos_search'
require_relative '../test__helper'

class TestQosSearch < Minitest::Test
  SearchResult = Struct.new(:items, :total_count, keyword_init: true)
  RateLimit = Struct.new(:remaining, keyword_init: true)

  def setup
    $loog = Loog::Buffer.new
    $judge = 'test-judge'
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
