# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024 Yegor Bugayenko
# License:: MIT
class TestWhoIsAlive < Jp::Test
  def test_finds_dead_users
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{}', headers: { 'X-RateLimit-Remaining' => '222' } }
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
end
