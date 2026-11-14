# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../../lib/who_of'
require_relative '../fake_github'
require_relative '../test__helper'

class TestWhoOf < Jp::Test
  def test_mentions_the_login
    $options = Judges::Options.new({})
    $global = {}
    $loog = Loog::NULL
    fact = Factbase.new.insert
    fact.who = 44
    Jp::FakeGithub.new(
      'GET /rate_limit' => { rate: { remaining: 222 } },
      'GET /user/44' => { id: 44, login: 'yegor256' }
    ).run do
      assert_equal('@yegor256', Jp.mention(fact))
    end
  end

  def test_falls_back_when_github_answers_not_found
    $options = Judges::Options.new({})
    $global = {}
    $loog = Loog::NULL
    fact = Factbase.new.insert
    fact.who = 44
    Jp::FakeGithub.new(
      'GET /rate_limit' => { rate: { remaining: 222 } },
      'GET /user/44' => [404, { message: 'Not Found' }]
    ).run do
      assert_equal('user #44', Jp.mention(fact))
    end
  end

  def test_falls_back_when_github_answers_forbidden
    $options = Judges::Options.new({})
    $global = {}
    $loog = Loog::NULL
    fact = Factbase.new.insert
    fact.who = 44
    Jp::FakeGithub.new(
      'GET /rate_limit' => { rate: { remaining: 222 } },
      'GET /user/44' => [403, { message: 'Resource not accessible by integration' }]
    ).run do
      assert_equal('user #44', Jp.mention(fact))
    end
  end

  def test_mentions_a_deleted_account_when_who_is_absent
    fact = Factbase.new.insert
    assert_equal('a user who has deleted the account', Jp.mention(fact))
  end
end
