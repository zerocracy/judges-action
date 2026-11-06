# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'judges/options'
require_relative '../../lib/humans'
require_relative '../test__helper'

class TestHumans < Minitest::Test
  def test_filters_a_single_numeric_login
    before = $options
    $options = Judges::Options.new(['bots=123'])
    assert_equal(['123'], Jp.bots)
    kept = Jp.human_comments([{ user: { login: '123', type: 'User' } }, { user: { login: 'alice', type: 'User' } }])
    assert_equal(['alice'], kept.map { |comment| comment.dig(:user, :login) })
  ensure
    $options = before
  end

  def test_reads_empty_and_comma_separated_bot_options
    before = $options
    { 'bots=' => [], 'bots=123,0pdd' => %w[123 0pdd], 'bots=0pdd' => ['0pdd'] }.each do |option, expected|
      $options = Judges::Options.new([option])
      assert_equal(expected, Jp.bots, option)
    end
    $options = Judges::Options.new([])
    assert_empty(Jp.bots)
  ensure
    $options = before
  end

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
