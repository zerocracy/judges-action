# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'loog'
require_relative '../../lib/qos_search'
require_relative '../test__helper'

class TestQosCapped < Minitest::Test
  def test_says_that_a_full_page_is_a_sample
    log = Loog::Buffer.new
    found = { items: Array.new(100) { |i| { number: i } } }
    assert(Jp.capped?(found, 'repo:foo/foo type:pr', judge: 'quality-of-service', loog: log))
    assert_includes(log.to_s, 'sample of the window')
  end

  def test_keeps_quiet_about_a_page_that_is_not_full
    log = Loog::Buffer.new
    found = { items: Array.new(3) { |i| { number: i } } }
    refute(Jp.capped?(found, 'repo:foo/foo type:pr', judge: 'quality-of-service', loog: log))
    assert_empty(log.to_s)
  end
end
