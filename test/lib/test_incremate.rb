# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
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
      cnt = %w[some_alpha some_beta some_gamma].count { |p| f[p] }
      assert_equal(2, cnt, "exactly 2 of 3 properties should be set with max_per_fact=2, got #{cnt}")
    end
    $global = nil
    $local = nil
    $loog = nil
    $options = nil
  end

  def test_incremate_recovers_from_partial_write
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
      File.write(File.expand_path('some_first.rb', dir), <<~RUBY)
        def some_first(_f)
          { some_first: 1, some_second: 2 }
        end
      RUBY
      time = Time.now - 60
      fb = Factbase.new
      f = fb.insert
      f.some_second = 2
      Jp.incremate(f, dir, 'some', epoch: time, kickoff: time)
      assert_equal(1, f.some_first, 'the property named after the file must still be collected')
      assert_equal([2], f['some_second'], 'the property already written before the interruption must not be duplicated')
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
      assert_operator(elapsed, :>=, 0.15, 'pause must apply between the two evaluations')
    end
    $global = nil
    $local = nil
    $loog = nil
    $options = nil
  end

  def test_incremate_remembers_empty_metric_after_factbase_roundtrip
    configure_incremate
    Dir.mktmpdir do |dir|
      File.write(File.expand_path('some_empty.rb', dir), <<~RUBY)
        def some_empty(_fact)
          $calls += 1
          { some_empty: [] }
        end
      RUBY
      $calls = 0
      time = Time.now - 60
      fb = Factbase.new
      fact = fb.insert
      Jp.incremate(fact, dir, 'some', epoch: time, kickoff: time)
      assert_equal(1, $calls)
      assert_nil(fact['some_empty'])
      assert_equal(['some_empty'], fact[Jp::INCREMATE_MARKER])
      copy = Factbase.new
      copy.import(fb.export)
      resumed = copy.query('(always)').each.to_a.first
      Jp.incremate(resumed, dir, 'some', epoch: time, kickoff: time)
      assert_equal(1, $calls, 'a persisted empty result must not be collected again')
      assert_nil(resumed['some_empty'])
    end
  ensure
    reset_incremate
  end

  def test_incremate_retries_metric_without_result
    configure_incremate
    Dir.mktmpdir do |dir|
      File.write(File.expand_path('some_empty.rb', dir), <<~RUBY)
        def some_empty(_fact)
          $calls += 1
          $calls == 1 ? {} : { some_empty: [] }
        end
      RUBY
      $calls = 0
      fact = Factbase.new.insert
      time = Time.now - 60
      Jp.incremate(fact, dir, 'some', epoch: time, kickoff: time)
      assert_equal(1, $calls)
      assert_nil(fact[Jp::INCREMATE_MARKER])
      Jp.incremate(fact, dir, 'some', epoch: time, kickoff: time)
      assert_equal(2, $calls)
      assert_equal(['some_empty'], fact[Jp::INCREMATE_MARKER])
      Jp.incremate(fact, dir, 'some', epoch: time, kickoff: time)
      assert_equal(2, $calls, 'a successful empty result must be remembered')
    end
  ensure
    reset_incremate
  end

  def test_incremate_marks_only_after_writing_all_values
    configure_incremate
    Dir.mktmpdir do |dir|
      File.write(File.expand_path('some_empty.rb', dir), <<~RUBY)
        def some_empty(_fact)
          $calls += 1
          if $calls == 1
            { some_empty: [], some_invalid: Object.new }
          else
            { some_empty: [] }
          end
        end
      RUBY
      $calls = 0
      fact = Factbase.new.insert
      time = Time.now - 60
      assert_raises(ArgumentError) do
        Jp.incremate(fact, dir, 'some', epoch: time, kickoff: time)
      end
      assert_nil(fact[Jp::INCREMATE_MARKER])
      Jp.incremate(fact, dir, 'some', epoch: time, kickoff: time)
      assert_equal(['some_empty'], fact[Jp::INCREMATE_MARKER])
      Jp.incremate(fact, dir, 'some', epoch: time, kickoff: time)
      assert_equal(2, $calls, 'a failed collection must remain retryable')
    end
  ensure
    reset_incremate
  end

  def test_incremate_keeps_non_empty_metrics_unchanged
    configure_incremate
    Dir.mktmpdir do |dir|
      File.write(File.expand_path('some_non_empty.rb', dir), <<~RUBY)
        def some_non_empty(_fact)
          $nonempty += 1
          { some_non_empty: 42 }
        end
      RUBY
      $nonempty = 0
      fact = Factbase.new.insert
      time = Time.now - 60
      2.times { Jp.incremate(fact, dir, 'some', epoch: time, kickoff: time) }
      assert_equal(1, $nonempty)
      assert_equal(42, fact.some_non_empty)
      assert_nil(fact[Jp::INCREMATE_MARKER])
    end
  ensure
    reset_incremate
  end

  private

  def configure_incremate
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      body: { rate: { remaining: 1000, limit: 1000 } }.to_json,
      headers: { 'X-RateLimit-Remaining' => '999' }
    )
    $global = {}
    $local = {}
    $loog = Loog::VERBOSE
    $options = Judges::Options.new({ 'lifetime' => 100, 'timeout' => 100 })
  end

  def reset_incremate
    $global = nil
    $local = nil
    $loog = nil
    $options = nil
  end
end
