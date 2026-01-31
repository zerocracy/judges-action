# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024 Yegor Bugayenko
# License:: MIT
class TestWhoHasName < Jp::Test
  using SmartFactbase

  def test_finds_name
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{"rate":{"remaining":222}}', headers: { 'X-RateLimit-Remaining' => '222' } }
    )
    stub_github(
      'https://api.github.com/user/444',
      body: { login: 'lebowski' }
    )
    fb = Factbase.new
    f = fb.insert
    f._id = 333
    f.who = 444
    f.where = 'github'
    f.what = 'issue-was-opened'
    load_it('who-has-name', fb)
    assert_equal(2, fb.query('(always)').each.to_a.size)
    assert_equal('lebowski', fb.query('(exists name)').each.first.name)
  end

  def test_ignores_who_when_not_found
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{"rate":{"remaining":222}}', headers: { 'X-RateLimit-Remaining' => '222' } }
    )
    stub_github(
      'https://api.github.com/user/444',
      body: '', status: 404
    )
    fb = Factbase.new
    f = fb.insert
    f._id = 999
    f.who = 444
    f.where = 'github'
    load_it('who-has-name', fb)
    assert_equal(1, fb.query('(exists who)').each.to_a.size)
  end

  def test_overwrite_name_if_user_login_changed
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/user/12', body: { login: 'user22', id: 12, type: 'User' })
    stub_github('https://api.github.com/user/13', body: { login: 'user3', id: 13, type: 'User' })
    stub_github(
      'https://api.github.com/user/14',
      status: 404,
      body: { message: 'Not Found', documentation_url: 'https://docs.github.com/rest', status: '404' }
    )
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
      load_it('who-has-name', fb)
      assert_equal(5, fb.all.size)
      assert(fb.one?(what: 'who-has-name', where: 'github', who: 10, name: 'user0', stale: 'who'))
      assert(fb.one?(what: 'who-has-name', where: 'github', who: 11, name: 'user1'))
      assert(fb.one?(what: 'who-has-name', where: 'github', who: 12, name: 'user22'))
      assert(fb.one?(what: 'who-has-name', where: 'github', who: 13, name: 'user3'))
      assert(fb.one?(what: 'who-has-name', where: 'github', who: 14, name: 'user4'))
    end
  end
end
