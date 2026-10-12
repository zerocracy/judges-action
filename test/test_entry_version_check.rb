# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative 'test__helper'

class TestEntryVersionCheck < Jp::Test
  def test_bounds_every_version_check_request
    body = File.read(File.join(File.expand_path('..', __dir__), 'entry.sh'))
    calls = body.scan(%r{^\s*resp=\$\(curl[^\n]*releases/latest[^\n]*$})
    refute_empty(calls, 'No version check request found in entry.sh')
    calls.each do |call|
      assert_includes(call, '--connect-timeout', "a version check request has no connect timeout: #{call}")
      assert_match(/--max-time|--retry-max-time/, call, "a version check request has no deadline: #{call}")
    end
  end
end
