# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'judges/options'
require_relative '../../lib/incremate'
require_relative '../test__helper'

class TestIncremateMarker < Minitest::Test
  def test_runs_an_empty_string_keyed_metric_only_once
    options = $options
    loog = $loog
    $options = Judges::Options.new({})
    $loog = Loog::NULL
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, 'some_empty.rb'), <<~RUBY)
        def some_empty(_f)
          { 'some_empty' => [], visits: 1 }
        end
      RUBY
      fact = Factbase.new.insert
      Fbe.stub(:over?, false) do
        2.times { Jp.incremate(fact, dir, 'some', avoid_duplicate: false) }
      end
      assert_equal([1], fact['visits'], 'a completed empty metric must not run again in the next cycle')
    end
  ensure
    $options = options
    $loog = loog
  end

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
