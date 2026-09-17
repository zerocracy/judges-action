# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'loog'
require 'minitest/mock'
require_relative '../../lib/cover_qo'
require_relative '../test__helper'

class TestCoverQoSmallGap < Minitest::Test
  def test_reports_a_gap_shorter_than_one_window
    fb = Factbase.new
    first = fb.insert
    first.what = 'test-judge'
    first.since = Time.parse('2025-01-01 00:00:00 UTC')
    first.when = Time.parse('2025-02-02 00:00:00 UTC')
    second = fb.insert
    second.what = 'test-judge'
    second.since = Time.parse('2025-03-05 00:00:00 UTC')
    second.when = Time.parse('2025-03-20 00:00:00 UTC')
    log = Loog::Buffer.new
    Fbe.stub(:fb, fb) do
      Jp.cover_qo(32, judge: 'test-judge', loog: log, today: Time.parse('2025-03-20 00:00:00 UTC'))
    end
    assert_includes(log.to_s, 'left unmeasured')
    assert_includes(log.to_s, '2025-02-02T00:00:00Z..2025-03-05T00:00:00Z')
  end
end
