# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../test__helper'

class TestWhoHasName < Jp::Test
  using SmartFactbase

  def test_finds_name
    rate_limit_up
    fb = Factbase.new
    f = fb.insert
    f._id = 333
    f.who = 444
    f.where = 'github'
    f.what = 'issue-was-opened'
    VCR.use_cassette('who-has-name/finds-name') do
      load_it('who-has-name', fb)
    end
    assert_equal(2, fb.query('(always)').each.to_a.size)
    assert_equal('lebowski', fb.query('(exists name)').each.first.name)
  end

  def test_ignores_who_when_not_found
    rate_limit_up
    fb = Factbase.new
    f = fb.insert
    f._id = 999
    f.who = 444
    f.where = 'github'
    VCR.use_cassette('who-has-name/ignores-who-when-not-found') do
      load_it('who-has-name', fb)
    end
    assert_equal(1, fb.query('(exists who)').each.to_a.size)
  end

  def test_does_not_crash_when_all_users_resolved
    rate_limit_up
    fb = Factbase.new
    load_it('who-has-name', fb)
    assert_equal(0, fb.all.size)
  end

  def test_overwrite_name_if_user_login_changed
    rate_limit_up
    fb = Factbase.new
    fb.with(
      _id: 1, what: 'who-has-name', where: 'github', who: 10, name: 'user0',
      when: Time.parse('2025-06-19 20:00:00 UTC'), stale: 'who'
    ).with(
      _id: 2, what: 'who-has-name', where: 'github', who: 11, name: 'user1',
      when: Time.parse('2025-06-22 20:00:00 UTC')
    ).with(
      _id: 3, what: 'who-has-name', where: 'github', who: 12, name: 'user2',
      when: Time.parse('2025-06-18 20:00:00 UTC')
    ).with(
      _id: 4, what: 'who-has-name', where: 'github', who: 13, name: 'user3',
      when: Time.parse('2025-06-16 20:00:00 UTC')
    ).with(
      _id: 5, what: 'who-has-name', where: 'github', who: 14, name: 'user4',
      when: Time.parse('2025-06-15 20:00:00 UTC')
    )
    Time.stub(:now, Time.parse('2025-06-23 22:00:00 UTC')) do
      VCR.use_cassette('who-has-name/overwrite-name-if-user-login-changed') do
        load_it('who-has-name', fb)
      end
      assert_equal(5, fb.all.size)
      assert(fb.one?(what: 'who-has-name', where: 'github', who: 10, name: 'user0', stale: 'who'))
      assert(fb.one?(what: 'who-has-name', where: 'github', who: 11, name: 'user1'))
      assert(fb.one?(what: 'who-has-name', where: 'github', who: 12, name: 'user22'))
      assert(fb.one?(what: 'who-has-name', where: 'github', who: 13, name: 'user3'))
      assert(fb.one?(what: 'who-has-name', where: 'github', who: 14, name: 'user4'))
    end
  end

  def test_marks_fact_stale_on_forbidden_user_lookup
    rate_limit_up
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-merged', repository: 42, issue: 44, who: 29_139_614, where: 'github')
    VCR.use_cassette('who-has-name/marks-fact-stale-on-forbidden-user-lookup') do
      load_it('who-has-name', fb)
    end
    fact = fb.query('(eq who 29139614)').each.first
    refute_nil(fact)
    assert_nil(
      fact['stale']&.first,
      'fact must not be marked stale on a transient 403; the cycle should retry on the next run'
    )
  end
end
