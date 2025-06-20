# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024 Yegor Bugayenko
# License:: MIT
class TestWhoHasName < Jp::Test
  def test_finds_name
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{}', headers: { 'X-RateLimit-Remaining' => '222' } }
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
    load_it('who-has-name', fb)
    assert_equal(2, fb.query('(always)').each.to_a.size)
    assert_equal('lebowski', fb.query('(exists name)').each.to_a.first.name)
  end

  def test_ignores_who_when_not_found
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{}', headers: { 'X-RateLimit-Remaining' => '222' } }
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
end
