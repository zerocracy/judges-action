# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'webmock/minitest'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2025 Yegor Bugayenko
# License:: MIT
class TestIsHumanOrRobot < Minitest::Test
  def test_handles_missing_github_user_gracefully
    WebMock.disable_net_connect!
    id = 444
    stub_github(
      "https://api.github.com/user/#{id}",
      body: {}, status: 404
    )
    stub_github(
      'https://api.github.com/rate_limit',
      body: {
        rate: { limit: 60, remaining: 59, reset: 1_728_464_472, used: 1, resource: 'core' }
      }
    )
    fb = Factbase.new
    fact = fb.insert
    fact.who = id
    fact.where = 'github'
    load_it('is-human-or-robot', fb)
    facts = fb.query("(eq who #{id})").each.to_a
    assert_equal(id, facts.first.who)
    assert_equal(
      "Can't find 'is_human' attribute out of [who, where]",
      assert_raises(RuntimeError) { facts.first.is_human }.message
    )
  end
end
