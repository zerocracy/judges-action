# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024 Yegor Bugayenko
# License:: MIT
class TestWhoIsAlive < Jp::Test
  using SmartFactbase

  def test_finds_dead_users
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{"rate":{"remaining":222}}', headers: { 'X-RateLimit-Remaining' => '222' } }
    )
    stub_github('https://api.github.com/user/444', status: 404, body: '')
    fb = Factbase.new
    f = fb.insert
    f._id = 1
    f.when = Time.now - (100 * 24 * 60 * 60)
    f.what = 'who-has-name'
    f.who = 444
    f.where = 'github'
    f.name = 'jack'
    load_it('who-is-alive', fb)
    assert_empty(fb.query('(exists who)').each.to_a)
    assert_empty(fb.query('(eq what "who-has-name")').each.to_a)
  end

  def test_add_stale_prop_for_not_found_users
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github(
      'https://api.github.com/user/10',
      status: 404,
      body: { message: 'Not Found', documentation_url: 'https://docs.github.com/rest', status: '404' }
    )
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
      load_it('who-is-alive', fb)
      assert_equal(6, fb.all.size)
      assert(fb.none?(what: 'who-has-name', where: 'github', who: 10, name: 'user0'))
      assert_equal('who', fb.pick(where: 'github', who: 10, name: 'user0').stale)
      assert(fb.one?(what: 'who-has-name', where: 'gitlab', who: 10, name: 'user0'))
      assert_nil(fb.pick(where: 'gitlab', who: 10, name: 'user0')['stale'])
    end
  end

  def test_skip_if_user_is_alive
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/user/10', body: { login: 'user0', id: 10, type: 'User' })
    stub_github('https://api.github.com/user/11', body: { login: 'user1', id: 11, type: 'User' })
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
      load_it('who-is-alive', fb)
      assert_equal(6, fb.all.size)
    end
  end
end
