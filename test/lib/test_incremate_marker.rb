# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'judges/options'
require_relative '../../lib/incremate'
require_relative '../test__helper'

class TestIncremateMarker < Minitest::Test
  def test_keeps_the_marker_that_came_back_as_a_string
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      body: { rate: { remaining: 1000, limit: 1000 } }.to_json,
      headers: { 'X-RateLimit-Remaining' => '999' }
    )
    $global = {}
    $local = {}
    $loog = Loog::NULL
    $options = Judges::Options.new({ 'lifetime' => 100, 'timeout' => 100 })
    Dir.mktmpdir do |dir|
      File.write(File.expand_path('some_property.rb', dir), <<~RUBY)
        def some_property(_f)
          { 'some_property' => 42 }
        end
      RUBY
      time = Time.now - 60
      f = Factbase.new.insert
      Jp.incremate(f, dir, 'some', avoid_duplicate: true, epoch: time, kickoff: time)
      assert_equal(42, f.some_property, 'a marker returned as a string must reach the fact')
    end
    $global = nil
    $local = nil
    $loog = nil
    $options = nil
  end
end
