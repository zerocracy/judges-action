# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'open3'
require_relative 'test__helper'

class TestEntryOptions < Jp::Test
  def test_passes_a_bare_key_without_an_equals_sign
    assert_equal(['--option=testing'], run_options("testing\n"))
  end

  def test_keeps_a_key_that_starts_with_a_dash
    assert_equal(['--option=-n=5'], run_options("-n=5\n"))
  end

  def test_keeps_the_value_that_holds_an_equals_sign
    assert_equal(['--option=token=a=b'], run_options("token=a=b\n"))
  end

  private

  def run_options(input)
    body = File.read(File.join(File.expand_path('..', __dir__), 'entry.sh'))
    block = body[/^declare -a options=\(\)\n(?:.*\n)*?done <<< "\$\{INPUT_OPTIONS\}"\n/]
    refute_nil(block, 'No options block found in entry.sh')
    out, _, status = Open3.capture3(
      { 'INPUT_OPTIONS' => input },
      'bash', '-c', "set -e -o pipefail\n#{block}\nprintf '%s\\n' \"${options[@]}\""
    )
    assert_equal(0, status.exitstatus, out)
    out.split("\n")
  end
end
