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

  def test_takes_account_of_bot_type_for_robot
    $options = Judges::Options.new({ 'bots' => '' })
    refute(Jp.human?({ login: 'ренован', type: 'Bot' }), 'an account of type Bot is taken for a human')
  end

  def test_takes_account_listed_among_bots_for_robot
    $options = Judges::Options.new({ 'bots' => '0pdd,Rultor' })
    refute(Jp.human?({ login: 'rultor', type: 'User' }), 'an account listed in the bots option is taken for a human')
  end

  def test_takes_plain_user_for_human
    $options = Judges::Options.new({ 'bots' => '0pdd,rultor' })
    assert(Jp.human?({ login: 'rultor2', type: 'User' }), 'a user not listed in the bots option is taken for a robot')
  end
end
