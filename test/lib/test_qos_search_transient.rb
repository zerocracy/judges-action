# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require_relative '../../lib/qos_search'
require_relative '../test__helper'

class TestQosSearchTransient < Jp::Test
  def setup
    WebMock.reset!
    WebMock.disable_net_connect!
    $options = Judges::Options.new({})
    $global = {}
    $loog = Loog::NULL
    $judge = 'test-qos-search-transient'
    Jp.qoreset
  end

  def test_answers_nil_on_a_connection_failure
    rate_limit_up
    stub_request(:get, /search\/issues/).to_raise(Faraday::ConnectionFailed.new('connection refused'))
    assert_nil(Jp.qosearch('repo:foo/foo type:issue'))
  end

  def test_stops_searching_after_abuse_detection
    rate_limit_up
    stub_request(:get, /search\/issues/).to_return(
      status: 403,
      body: { message: 'You have triggered an abuse detection mechanism' }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )
    assert_nil(Jp.qosearch('repo:foo/foo type:issue'))
  end
end
