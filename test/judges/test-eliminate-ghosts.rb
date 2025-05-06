# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2025 Yegor Bugayenko
# License:: MIT
class TestEliminateGhosts < Jp::Test
  def test_delete_who_if_user_not_found
    WebMock.disable_net_connect!
    stub_github('https://api.github.com/rate_limit', body: {})
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
    assert_equal(5, fb.query('(exists who)').each.to_a.size)
    assert_equal(4, fb.query('(not (exists who))').each.to_a.size)
    assert_equal(3, fb.query('(and (eq where "github") (exists who))').each.to_a.size)
    assert_equal(3, fb.query('(and (eq where "github") (not (exists who)))').each.to_a.size)
    assert_equal(2, fb.query('(and (eq where "gitlab") (exists who))').each.to_a.size)
    assert_equal(1, fb.query('(and (eq where "gitlab") (not (exists who)))').each.to_a.size)
  end
end
