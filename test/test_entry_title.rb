# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative 'test__helper'

class TestEntryTitle < Jp::Test
  def test_bounds_the_connection_of_the_run_title_request
    body = File.read(File.join(File.expand_path('..', __dir__), 'entry.sh')).gsub("\\\n", ' ')
    call = body[%r{^\s*curl[^\n]*-X PATCH[^\n]*actions/runs[^\n]*$}].to_s
    assert_includes(call, '--connect-timeout', "the run title request has no connect timeout: #{call}")
  end

  def test_bounds_the_transfer_of_the_run_title_request
    body = File.read(File.join(File.expand_path('..', __dir__), 'entry.sh')).gsub("\\\n", ' ')
    call = body[%r{^\s*curl[^\n]*-X PATCH[^\n]*actions/runs[^\n]*$}].to_s
    assert_includes(call, '--max-time', "the run title request has no deadline for the whole transfer: #{call}")
  end
end
