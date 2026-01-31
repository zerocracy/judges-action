# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'judges/options'
require 'factbase'
require_relative '../../lib/incremate'
require_relative '../test__helper'

# Test.
class TestIncremate < Minitest::Test
  def test_incremate
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      body: { rate: { remaining: 1000, limit: 1000 } }.to_json,
      headers: { 'X-RateLimit-Remaining' => '999' }
    )
    $global = {}
    $local = {}
    $loog = Loog::VERBOSE # Loog::NULL
    $options = Judges::Options.new({ 'lifetime' => 100, 'timeout' => 100 })
    Dir.mktmpdir do |dir|
      File.write(File.expand_path('some_property.rb', dir), <<~RUBY)
        def some_property(_f)
          { some_property: 42 }
        end
      RUBY
      time = Time.now - 60
      fb = Factbase.new
      f = fb.insert
      Jp.incremate(f, dir, 'some', avoid_duplicate: true, epoch: time, kickoff: time)
      assert_equal(42, f.some_property)
    end
    $global = nil
    $local = nil
    $loog = nil
    $options = nil
  end
end
