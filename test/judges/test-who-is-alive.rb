# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../test__helper'

class TestWhoIsAlive < Jp::Test
  using SmartFactbase

  def test_finds_dead_users
    rate_limit_up
    fb = Factbase.new
    f = fb.insert
    f._id = 1
    f.when = Time.now - (100 * 24 * 60 * 60)
    f.what = 'who-has-name'
    f.who = 444
    f.where = 'github'
    f.name = 'jack'
    VCR.use_cassette('who-is-alive/finds-dead-users') do
      load_it('who-is-alive', fb)
    end
    assert_empty(fb.query('(exists who)').each.to_a)
    assert_empty(fb.query('(eq what "who-has-name")').each.to_a)
  end

  def test_add_stale_prop_for_not_found_users
    rate_limit_up
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
      VCR.use_cassette('who-is-alive/add-stale-prop-for-not-found-users') do
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
    rate_limit_up
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
      VCR.use_cassette('who-is-alive/skip-if-user-is-alive') do
        load_it('who-is-alive', fb)
      end
      assert_equal(6, fb.all.size)
    end
  end

  def test_handles_forbidden_user_lookup_without_raising
    rate_limit_up
    fb = Factbase.new
    fb.with(
      _id: 1, what: 'who-has-name', where: 'github', who: 29_139_614,
      name: 'someone', when: Time.now - (3 * 86_400)
    )
    VCR.use_cassette('who-is-alive/handles-forbidden-user-lookup-without-raising') do
      load_it('who-is-alive', fb)
    end
    refute_empty(
      fb.query('(eq what "who-has-name")').each.to_a,
      'who-is-alive must not delete the who-has-name fact on a transient 403; the cycle should retry on the next run'
    )
  end
end
