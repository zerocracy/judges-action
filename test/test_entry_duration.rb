# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative 'test__helper'

class TestEntryDuration < Jp::Test
  def test_measures_the_duration_with_a_clock_that_nobody_adjusts
    body = File.read(File.join(File.expand_path('..', __dir__), 'entry.sh'))
    refute_includes(body, 'date +%s', 'the wall clock must not be used to measure the duration')
    assert_equal(2, body.scan('$(($(uptime_seconds) - start))').size)
  end

  def test_reads_whole_seconds_from_the_uptime
    body = File.read(File.join(File.expand_path('..', __dir__), 'entry.sh'))
    func = body[/^uptime_seconds\(\) \{\n(?:.*\n)*?\}\n/]
    refute_nil(func, 'entry.sh must define uptime_seconds')
    out = IO.popen(['bash', '-c', "#{func}\nuptime_seconds"], &:read)
    assert_match(/\A\d+\n\z/, out)
  end
end
