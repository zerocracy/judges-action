# frozen_string_literal: true

require 'factbase'
# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'judges/options'
require_relative '../../lib/incremate'
require_relative '../test__helper'

class TestIncremate < Minitest::Test
  def test_incremate
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      body: { rate: { remaining: 1000, limit: 1000 } }.to_json,
      headers: { 'X-RateLimit-Remaining' => '999' }
    )
    $global = {}
    $local = {}
    $loog = Loog::VERBOSE
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

  def test_incremate_respects_max_per_fact
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      body: { rate: { remaining: 1000, limit: 1000 } }.to_json,
      headers: { 'X-RateLimit-Remaining' => '999' }
    )
    $global = {}
    $local = {}
    $loog = Loog::VERBOSE
    $options = Judges::Options.new({ 'lifetime' => 100, 'timeout' => 100 })
    Dir.mktmpdir do |dir|
      File.write(File.expand_path('some_alpha.rb', dir), <<~RUBY)
        def some_alpha(_f)
          { some_alpha: 1 }
        end
      RUBY
      File.write(File.expand_path('some_beta.rb', dir), <<~RUBY)
        def some_beta(_f)
          { some_beta: 2 }
        end
      RUBY
      File.write(File.expand_path('some_gamma.rb', dir), <<~RUBY)
        def some_gamma(_f)
          { some_gamma: 3 }
        end
      RUBY
      time = Time.now - 60
      fb = Factbase.new
      f = fb.insert
      Jp.incremate(f, dir, 'some', max_per_fact: 2, epoch: time, kickoff: time)
      assert(f.some_alpha, 'alpha should be set')
      assert(f.some_beta, 'beta should be set')
      assert_nil(f['some_gamma'], 'gamma should NOT be set (max_per_fact=2 caps at 2)')
    end
    $global = nil
    $local = nil
    $loog = nil
    $options = nil
  end

  def test_incremate_pauses_between_evaluations
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      body: { rate: { remaining: 1000, limit: 1000 } }.to_json,
      headers: { 'X-RateLimit-Remaining' => '999' }
    )
    $global = {}
    $local = {}
    $loog = Loog::VERBOSE
    $options = Judges::Options.new({ 'lifetime' => 100, 'timeout' => 100 })
    Dir.mktmpdir do |dir|
      File.write(File.expand_path('some_alpha.rb', dir), <<~RUBY)
        def some_alpha(_f)
          { some_alpha: 1 }
        end
      RUBY
      File.write(File.expand_path('some_beta.rb', dir), <<~RUBY)
        def some_beta(_f)
          { some_beta: 2 }
        end
      RUBY
      time = Time.now - 60
      fb = Factbase.new
      f = fb.insert
      started = Time.now
      Jp.incremate(f, dir, 'some', avoid_duplicate: true, pause: 0.2, epoch: time, kickoff: time)
      elapsed = Time.now - started
      assert_equal(1, f.some_alpha)
      assert_equal(2, f.some_beta)
      assert_operator(elapsed, :>=, 0.2, 'pause must apply between the two evaluations')
      assert_operator(elapsed, :<, 0.5, 'pause must not apply before the first or after the last evaluation')
    end
    $global = nil
    $local = nil
    $loog = nil
    $options = nil
  end
end
