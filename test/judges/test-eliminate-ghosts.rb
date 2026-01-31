# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2025 Yegor Bugayenko
# License:: MIT
class TestEliminateGhosts < Jp::Test
  using SmartFactbase

  def test_delete_who_if_user_not_found
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{"rate":{"remaining":222}}', headers: { 'X-RateLimit-Remaining' => '222' } }
    )
    stub_github(
      'https://api.github.com/user/526301',
      body: { login: 'yegor256', id: 526_301, type: 'User', site_admin: false }
    )
    stub_github(
      'https://api.github.com/user/526302',
      body: { login: 'yegor257', id: 526_302, type: 'User', site_admin: false }
    )
    stub_github('https://api.github.com/user/404001', body: '', status: 404)
    stub_github('https://api.github.com/user/404002', body: '', status: 404)
    fb = Factbase.new
    fb.insert.then do |f|
      f._id = 1
      f.where = 'github'
      f.who = 526_301
    end
    fb.insert.then do |f|
      f._id = 2
      f.where = 'github'
      f.who = 404_001
    end
    fb.insert.then do |f|
      f._id = 3
      f.where = 'github'
      f.who = 526_301
    end
    fb.insert.then do |f|
      f._id = 4
      f.where = 'github'
      f.who = 404_002
    end
    fb.insert.then do |f|
      f._id = 5
      f.where = 'github'
      f.who = 526_302
    end
    fb.insert.then do |f|
      f._id = 6
      f.where = 'gitlab'
      f.who = 404_003
    end
    fb.insert.then do |f|
      f._id = 7
      f.where = 'gitlab'
      f.who = 526_303
    end
    fb.insert.then do |f|
      f._id = 8
      f.where = 'github'
    end
    fb.insert.then do |f|
      f._id = 9
      f.where = 'gitlab'
    end
    load_it('eliminate-ghosts', fb)
    assert_equal(7, fb.query('(exists who)').each.to_a.size)
    assert_equal(2, fb.query('(and (exists who) (exists stale))').each.to_a.size)
    assert_equal(2, fb.query('(absent who)').each.to_a.size)
    assert_equal(5, fb.query('(and (eq where "github") (exists who))').each.to_a.size)
    assert_equal(1, fb.query('(and (eq where "github") (absent who))').each.to_a.size)
    assert_equal(2, fb.query('(and (eq where "gitlab") (exists who))').each.to_a.size)
    assert_equal(1, fb.query('(and (eq where "gitlab") (absent who))').each.to_a.size)
  end

  def test_process_unique_users_first_and_set_stale_property_later_for_other_facts
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{"rate":{"remaining":222}}', headers: { 'X-RateLimit-Remaining' => '222' } }
    )
    stub_github('https://api.github.com/user/111', body: {}, status: 404)
    stub_github('https://api.github.com/user/222', body: {}, status: 404)
    stub_github('https://api.github.com/user/333', body: { login: 'user333', id: 333, type: 'User' })
    stub_github('https://api.github.com/user/444', body: {}, status: 404)
    fb = Factbase.new
    fb.with(_id: 1, where: 'github', who: 111, what: 'something-a')
      .with(_id: 2, where: 'github', who: 111, what: 'something-b')
      .with(_id: 3, where: 'github', who: 222, what: 'something-c')
      .with(_id: 4, where: 'github', who: 222, what: 'something-d')
      .with(_id: 5, where: 'github', who: 222, what: 'something-e')
      .with(_id: 6, where: 'github', who: 333, what: 'something-f')
      .with(_id: 7, where: 'github', who: 333, what: 'something-g')
      .with(_id: 8, where: 'github', who: 444, what: 'something-h')
      .with(_id: 9, where: 'github', who: 444, what: 'something-i')
      .with(_id: 10, where: 'github', who: 555, what: 'something-j', stale: 'who')
      .with(_id: 11, where: 'github', who: 555, what: 'something-k', stale: 'who')
      .with(_id: 12, where: 'github', who: 555, what: 'something-l', stale: 'who')
    load_it('eliminate-ghosts', fb)
    assert_equal(2, fb.picks(where: 'github', who: 111, stale: 'who').count)
    assert_equal(3, fb.picks(where: 'github', who: 222, stale: 'who').count)
    assert_equal(2, fb.picks(where: 'github', who: 444, stale: 'who').count)
    assert_equal(3, fb.picks(where: 'github', who: 555, stale: 'who').count)
    assert(fb.none?(where: 'github', who: 333, stale: 'who'))
    assert(fb.has?(where: 'github', who: 333))
  end
end
