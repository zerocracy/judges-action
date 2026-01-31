# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative '../../lib/supervision'
require_relative '../test__helper'

# Test.
class TestSupervision < Minitest::Test
  def test_supervision
    $loog = Loog::Buffer.new
    assert_raises(RuntimeError) do
      Jp.supervision({ 'repo' => 'zerocracy/judges-action', 'issue' => 125 }) do
        raise 'some error'
      end
    end
    $loog.to_s.then do |s|
      assert_match('RuntimeError: some error', s)
      assert_match('"repo": "zerocracy/judges-action"', s)
      assert_match('"issue": 125', s)
    end
  end
end
