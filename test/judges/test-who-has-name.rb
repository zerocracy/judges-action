# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'minitest/autorun'
require 'webmock/minitest'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024 Yegor Bugayenko
# License:: MIT
class TestWhoHasName < Minitest::Test
  def test_finds_name
    WebMock.disable_net_connect!
    stub_github(
      'https://api.github.com/user/444',
      body: { login: 'lebowski' }
    )
    fb = Factbase.new
    f = fb.insert
    f.who = 444
    f.where = 'github'
    load_it('who-has-name', fb)
    assert_equal(2, fb.query('(always)').each.to_a.size)
    assert_equal('lebowski', fb.query('(exists name)').each.to_a.first.name)
  end
end
