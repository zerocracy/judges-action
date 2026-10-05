# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'judges/options'
require_relative '../../lib/incremate'
require_relative '../test__helper'

class TestIncrematePause < Minitest::Test
  def test_stops_when_the_pause_has_eaten_the_deadline
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      body: { rate: { remaining: 1000, limit: 1000 } }.to_json,
      headers: { 'X-RateLimit-Remaining' => '999' }
    )
    $global = {}
    $local = {}
    $loog = Loog::NULL
    $options = Judges::Options.new({ 'lifetime' => 10, 'timeout' => 10 })
    Dir.mktmpdir do |dir|
      %w[first second].each do |name|
        File.write(File.expand_path("some_#{name}.rb", dir), <<~RUBY)
          def some_#{name}(_f)
            { some_#{name}: 42 }
          end
        RUBY
      end
      time = Time.now - 8
      f = Factbase.new.insert
      Jp.incremate(f, dir, 'some', avoid_duplicate: true, pause: 2, epoch: time, kickoff: time)
      assert_equal(42, f.some_first)
      assert_nil(f['some_second'])
    end
    $global = nil
    $local = nil
    $loog = nil
    $options = nil
  end
end
