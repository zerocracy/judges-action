# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'open3'
require_relative 'test__helper'

class TestEntryCache < Jp::Test
  def test_replaces_an_empty_min_age_with_the_default
    assert_equal(
      ['--option=foo=привет', '--option=sqlite_cache_min_age=3600'],
      run_block(['--option=sqlite_cache_min_age=', '--option=foo=привет']),
      'empty sqlite_cache_min_age is not replaced by the default'
    )
  end

  def test_keeps_a_configured_min_age
    seed = Random.new_seed
    age = "--option=sqlite_cache_min_age=#{Random.new(seed).rand(1..99_999)}"
    assert_equal([age], run_block([age]), "configured sqlite_cache_min_age is not kept, seed #{seed}")
  end

  def test_adds_the_default_when_min_age_is_absent
    assert_equal(
      ['--option=bar=', '--option=sqlite_cache_min_age=3600'],
      run_block(['--option=bar=']),
      'absent sqlite_cache_min_age does not receive the default'
    )
  end

  private

  def run_block(options)
    body = File.read(File.join(File.expand_path('..', __dir__), 'entry.sh'))
    block = body[/^cache_min_age=false\n(?:.*\n)*?^fi\n/]
    refute_nil(block, 'No cache_min_age block found in entry.sh')
    out, = Open3.capture3(
      'bash', '-c',
      "set -e -o pipefail\noptions=(\"$@\")\n#{block}printf '%s\\n' \"${options[@]}\"",
      'bash', *options
    )
    out.lines(chomp: true)
  end
end
