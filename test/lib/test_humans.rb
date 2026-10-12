# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'judges/options'
require_relative '../../lib/humans'
require_relative '../test__helper'

class TestHumans < Minitest::Test
  def test_filters_a_bot_whatever_the_case_of_its_login
    $options = Judges::Options.new({ 'bots' => 'SomeBot,other-bot' })
    kept =
      Jp.human_comments(
        [
          { user: { login: 'somebot', type: 'User' } },
          { user: { login: 'SomeBot', type: 'User' } },
          { user: { login: 'alice', type: 'User' } }
        ]
      )
    assert_equal(['alice'], kept.map { |c| c.dig(:user, :login) })
  end
end
