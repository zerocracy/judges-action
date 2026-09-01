# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../fake_github'
require_relative '../test__helper'

class TestWhoIsAlive < Jp::Test
  using SmartFactbase

  def test_finds_dead_users
    fb = Factbase.new
    f = fb.insert
    f._id = 1
    f.when = Time.now - (100 * 24 * 60 * 60)
    f.what = 'who-has-name'
    f.who = 444
    f.where = 'github'
    f.name = 'jack'
    Jp::FakeGithub.new(
      'GET /rate_limit' => { rate: { remaining: 222 } },
      'GET /user/444' => 404
    ).run do
      load_it('who-is-alive', fb)
    end
    assert_empty(fb.query('(exists who)').each.to_a)
    assert_empty(fb.query('(eq what "who-has-name")').each.to_a)
  end

  def test_add_stale_prop_for_not_found_users
    fb = Factbase.new
    fb.with(_id: 1, where: 'github', who: 10, name: 'user0')
      .with(_id: 2, where: 'github', who: 11, name: 'user1')
      .with(_id: 3, where: 'github', who: 12, name: 'user2')
      .with(_id: 4, where: 'gitlab', who: 10, name: 'user0')
      .with(
        _id: 5, what: 'who-has-name', where: 'github', who: 10, name: 'user0',
        when: Time.parse('2025-06-23 20:00:00 UTC')
      )
      .with(
        _id: 6, what: 'who-has-name', where: 'github', who: 12, name: 'user2',
        when: Time.parse('2025-06-24 20:00:00 UTC')
      )
      .with(
        _id: 7, what: 'who-has-name', where: 'gitlab', who: 10, name: 'user0',
        when: Time.parse('2025-06-23 20:00:00 UTC')
      )
    Time.stub(:now, Time.parse('2025-06-25 22:00:00 UTC')) do
      Jp::FakeGithub.new(
        'GET /rate_limit' => { rate: { remaining: 222 } },
        'GET /user/10' => [404, { message: 'Not Found' }]
      ).run do
        load_it('who-is-alive', fb)
      end
      assert_equal(6, fb.all.size)
      assert(fb.none?(what: 'who-has-name', where: 'github', who: 10, name: 'user0'))
      assert_equal('who', fb.pick(where: 'github', who: 10, name: 'user0').stale)
      assert(fb.one?(what: 'who-has-name', where: 'gitlab', who: 10, name: 'user0'))
      assert_nil(fb.pick(where: 'gitlab', who: 10, name: 'user0')['stale'])
    end
  end

  def test_skip_if_user_is_alive
    fb = Factbase.new
    fb.with(_id: 1, where: 'github', who: 10, name: 'user0')
      .with(_id: 2, where: 'github', who: 11, name: 'user1')
      .with(_id: 3, where: 'gitlab', who: 11, name: 'user1')
      .with(
        _id: 4, what: 'who-has-name', where: 'github', who: 10, name: 'user0',
        when: Time.parse('2025-06-23 20:00:00 UTC')
      )
      .with(
        _id: 5, what: 'who-has-name', where: 'github', who: 11, name: 'user1',
        when: Time.parse('2025-06-23 20:00:00 UTC')
      )
      .with(
        _id: 6, what: 'who-has-name', where: 'gitlab', who: 11, name: 'user1',
        when: Time.parse('2025-06-23 20:00:00 UTC')
      )
    Time.stub(:now, Time.parse('2025-06-25 22:00:00 UTC')) do
      Jp::FakeGithub.new(
        'GET /rate_limit' => { rate: { remaining: 222 } },
        'GET /user/10' => { login: 'user0', id: 10, type: 'User' },
        'GET /user/11' => { login: 'user1', id: 11, type: 'User' }
      ).run do
        load_it('who-is-alive', fb)
      end
      assert_equal(6, fb.all.size)
    end
  end

  def test_keeps_fact_on_forbidden_user_lookup
    fb = Factbase.new
    fb.with(
      _id: 1, what: 'who-has-name', where: 'github', who: 29_139_614,
      name: 'someone', when: Time.now - (3 * 86_400)
    )
    Jp::FakeGithub.new(
      'GET /rate_limit' => { rate: { remaining: 222 } },
      'GET /user/29139614' => [403, { message: 'Resource not accessible by integration' }]
    ).run do
      load_it('who-is-alive', fb)
    end
    refute_empty(
      fb.query('(eq what "who-has-name")').each.to_a,
      'who-is-alive must not delete the who-has-name fact on a transient 403; the cycle should retry on the next run'
    )
  end
end
