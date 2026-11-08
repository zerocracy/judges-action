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

  def test_answers_nil_on_every_transient_class
    rate_limit_up
    octo = Fbe.octo
    [
      Octokit::ServerError.new(status: 500, body: '{}', response_headers: {}),
      Faraday::ConnectionFailed.new('connection refused'),
      Faraday::TimeoutError.new('timed out'),
      Net::OpenTimeout.new,
      Net::ReadTimeout.new,
      SocketError.new('socket error'),
      Errno::ECONNRESET.new,
      Errno::ETIMEDOUT.new
    ].each do |error|
      octo.stub(:search_issues, proc { raise(error) }) do
        assert_nil(Jp.qosearch('repo:foo/foo type:issue'), "no nil for #{error.class}")
      end
      refute(Jp.instance_variable_get(:@offquota)[$judge], "#{error.class} latched the off-quota flag")
    end
  end

  def test_answers_nil_on_a_connection_failure_over_http
    rate_limit_up
    stub_request(:get, %r{search/issues}).to_raise(Faraday::ConnectionFailed.new('connection refused'))
    assert_nil(Jp.qosearch('repo:foo/foo type:issue'))
  end

  def test_lets_a_foreign_no_method_error_out
    octo = Minitest::Mock.new
    octo.expect(:get, nil) { raise(NoMethodError.new('foreign', :foo)) }
    error = Fbe.stub(:octo, octo) { assert_raises(NoMethodError) { Jp.qosearch('repo:foo/foo type:issue') } }
    assert_equal(:foo, error.name)
  end

  def test_stops_searching_after_abuse_detection
    rate_limit_up
    stub_request(:get, %r{search/issues}).to_return(
      status: 403,
      body: { message: 'You have triggered an abuse detection mechanism' }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )
    assert_nil(Jp.qosearch('repo:foo/foo type:issue'))
  end
end
