# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'tmpdir'
require_relative '../../lib/incremate'
require_relative '../test__helper'

class TestIncremateTime < Jp::Test
  def setup
    super
    rate_limit_up
    $global = {}
    $local = {}
    $loog = Loog::NULL
    $options = Judges::Options.new({ 'lifetime' => 100, 'timeout' => 100 })
  end

  def teardown
    $global = nil
    $local = nil
    $loog = nil
    $options = nil
    super
  end

  def test_keeps_a_scalar_time_marker_for_both_key_types
    [:timing_stamp, 'timing_stamp'].each do |key|
      fact = evaluate("{ #{key.inspect} => stamp }")
      assert_equal([Time.utc(2026, 10, 14, 12, 34, 56)], fact['timing_stamp'])
    end
  end

  def test_keeps_a_scalar_time_in_a_secondary_property
    fact = evaluate('{ timing_stamp: 1, collected_at: stamp }')
    assert_equal([Time.utc(2026, 10, 14, 12, 34, 56)], fact['collected_at'])
    assert_equal([1], fact['timing_stamp'])
  end

  def test_keeps_array_values_and_ignores_nil
    fact = evaluate('{ timing_stamp: [stamp], tags: ["one", "two"], empty: nil }')
    assert_equal([Time.utc(2026, 10, 14, 12, 34, 56)], fact['timing_stamp'])
    assert_equal(%w[one two], fact['tags'])
    assert_nil(fact['empty'])
  end

  private

  def evaluate(result)
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, 'timing_stamp.rb'), <<~RUBY)
        def timing_stamp(_fact)
          stamp = Time.utc(2026, 10, 14, 12, 34, 56)
          #{result}
        end
      RUBY
      fact = Factbase.new.insert
      Jp.incremate(fact, dir, 'timing', epoch: Time.now, kickoff: Time.now)
      fact
    end
  end
end
