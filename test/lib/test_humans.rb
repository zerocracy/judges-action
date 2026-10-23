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

  def test_lets_in_a_person
    $options = Judges::Options.new({})
    assert(Jp.human?('alice', 'User'), 'a User is a person, whatever the bots option says')
  end

  def test_keeps_out_an_account_github_calls_a_bot
    $options = Judges::Options.new({})
    refute(Jp.human?('copilot-pull-request-reviewer', 'Bot'), 'a Bot account is not a person')
  end

  def test_keeps_out_a_login_from_the_bots_option
    $options = Judges::Options.new({ 'bots' => 'CodeRabbitAI' })
    refute(
      Jp.human?('coderabbitai', 'User'),
      'a login from the bots option is not a person, whatever the case of its letters'
    )
  end

  def test_lets_in_an_author_we_know_nothing_about
    $options = Judges::Options.new({})
    assert(Jp.human?(nil, nil), 'an author neither fbe nor the query reports is a person, not a bot')
  end
end
