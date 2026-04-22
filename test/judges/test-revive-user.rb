# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'octokit'
require_relative '../test__helper'

class TestReviveUser < Jp::Test
  using SmartFactbase

  def test_stale_user_stays_stale_when_github_returns_403
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github(
      'https://api.github.com/user/29139614',
      status: 403,
      body: { message: 'Resource not accessible by integration' }
    )
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-merged', repository: 42, issue: 44,
            who: 29_139_614, where: 'github', stale: 'who')
    load_it('revive-user', fb)
    fact = fb.query('(eq who 29139614)').each.first
    refute_nil(fact)
    assert_equal(
      'who', fact.stale,
      'fact should still be stale after 403 — we cannot confirm the user is alive'
    )
  end
end