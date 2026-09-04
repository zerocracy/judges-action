# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../fake_github'
require_relative '../test__helper'

class TestReviveUser < Jp::Test
  using SmartFactbase

  def test_stale_user_stays_stale_on_forbidden
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-merged', repository: 42, issue: 44, who: 29_139_614, where: 'github', stale: 'who')
    Jp::FakeGithub.new(
      'GET /rate_limit' => { resources: { search: { remaining: 30, limit: 30 } }, rate: { remaining: 1000 } },
      'GET /user/29139614' => [403, { message: 'Resource not accessible by integration' }]
    ).run do
      load_it('revive-user', fb)
    end
    assert_equal(
      'who', fb.pick(who: 29_139_614).stale,
      'the fact lost its staleness after a 403, while the user was never confirmed alive'
    )
  end
end
