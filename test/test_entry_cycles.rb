# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'open3'
require_relative 'test__helper'

class TestEntryCycles < Jp::Test
  def test_rejects_a_cycle_count_that_is_not_positive
    %w[0 00 007 -1 abc].each do |v|
      code, err = run_block('INPUT_CYCLES' => v)
      refute_equal(0, code, "INPUT_CYCLES=#{v.inspect} was accepted")
      assert_includes(err, 'INPUT_CYCLES must be a positive integer')
    end
  end

  def test_accepts_a_positive_cycle_count
    %w[1 2 30].each do |v|
      code, = run_block('INPUT_CYCLES' => v)
      assert_equal(0, code, "INPUT_CYCLES=#{v.inspect} was refused")
    end
  end

  def test_falls_back_to_the_default_when_the_input_is_absent
    code, = run_block('INPUT_CYCLES' => '')
    assert_equal(0, code)
  end

  private

  def run_block(env)
    body = File.read(File.join(File.expand_path('..', __dir__), 'entry.sh'))
    block = body[/^cycles=\$\{INPUT_CYCLES\}\n(?:.*\n)*?^fi\n/]
    refute_nil(block, 'No cycles block found in entry.sh')
    _, err, status = Open3.capture3(env, 'bash', '-c', "set -e -o pipefail\n#{block}")
    [status.exitstatus, err]
  end
end
