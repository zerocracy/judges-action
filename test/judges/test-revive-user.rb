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

  def test_keeps_other_lost_user_stale
    fb = revived
    assert_equal(['who'], fb.pick(issue: 46)['stale'], 'a user that is still lost was revived')
  end

  def test_revives_every_fact_of_found_user
    fb = revived
    assert_nil(fb.pick(issue: 44)['stale'], 'the first fact of the found user stayed stale')
    assert_nil(fb.pick(issue: 45)['stale'], 'the second fact of the found user stayed stale')
  end

  def test_keeps_other_staleness_of_found_user
    fb = revived
    assert_equal(['repository'], fb.pick(issue: 47)['stale'], 'a fact stale for another reason was revived')
  end

  private

  def revived
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-merged', repository: 42, issue: 44, who: 5, where: 'github', stale: 'who')
      .with(_id: 2, what: 'issue-was-opened', repository: 42, issue: 45, who: 5, where: 'github', stale: 'who')
      .with(_id: 3, what: 'issue-was-opened', repository: 42, issue: 46, who: 6, where: 'github', stale: 'who')
      .with(_id: 4, what: 'issue-was-opened', repository: 42, issue: 47, who: 5, where: 'github', stale: 'repository')
    Jp::FakeGithub.new(
      'GET /rate_limit' => { resources: { search: { remaining: 30, limit: 30 } }, rate: { remaining: 1000 } },
      'GET /user/5' => { id: 5, login: 'alive' },
      'GET /user/6' => [404, { message: 'Not Found' }]
    ).run do
      load_it('revive-user', fb)
    end
    fb
  end
end
