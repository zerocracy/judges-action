# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'open3'
require_relative 'test__helper'

class TestEntryMinutes < Jp::Test
  def test_rejects_a_timeout_that_is_not_a_positive_integer
    ['abc', '0', '-5', '1.5', ''].each do |v|
      next if v.empty?
      code, err = run_block('timeout', 'INPUT_TIMEOUT' => v)
      refute_equal(0, code, "INPUT_TIMEOUT=#{v.inspect} was accepted")
      assert_includes(err, 'INPUT_TIMEOUT must be a positive integer')
    end
  end

  def test_rejects_a_lifetime_that_is_not_a_positive_integer
    ['abc', '0', '-5', '1.5'].each do |v|
      code, err = run_block('lifetime', 'INPUT_LIFETIME' => v)
      refute_equal(0, code, "INPUT_LIFETIME=#{v.inspect} was accepted")
      assert_includes(err, 'INPUT_LIFETIME must be a positive integer')
    end
  end

  def test_accepts_a_positive_integer_and_turns_it_into_seconds
    code, = run_block('timeout', 'INPUT_TIMEOUT' => '7')
    assert_equal(0, code)
    code, = run_block('lifetime', 'INPUT_LIFETIME' => '7')
    assert_equal(0, code)
  end

  def test_falls_back_to_the_default_when_the_input_is_absent
    code, = run_block('timeout', 'INPUT_TIMEOUT' => '')
    assert_equal(0, code)
    code, = run_block('lifetime', 'INPUT_LIFETIME' => '')
    assert_equal(0, code)
  end

  private

  def run_block(name, env)
    body = File.read(File.join(File.expand_path('..', __dir__), 'entry.sh'))
    block = body[/^#{name}=\$\{INPUT_#{name.upcase}\}\n(?:.*\n)*?#{name}=\$\(\(#{name} \* 60\)\)\n/]
    refute_nil(block, "No #{name} block found in entry.sh")
    _, err, status = Open3.capture3(env, 'bash', '-c', "set -e -o pipefail\n#{block}")
    [status.exitstatus, err]
  end
end
