# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2025 Yegor Bugayenko
# License:: MIT
class TestIsHumanOrRobot < Jp::Test
  using SmartFactbase

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

  def test_identify_user_as_bot_or_human
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/user/15', body: { login: 'rultor', id: 15, type: 'User' })
    stub_github('https://api.github.com/user/16', body: { login: '0pdd', id: 16, type: 'User' })
    stub_github('https://api.github.com/user/17', body: { login: 'other_bot', id: 17, type: 'Bot' })
    stub_github('https://api.github.com/user/18', body: { login: 'user4', id: 18, type: 'User' })
    fb = Factbase.new
    fb.with(where: 'github', what: 'issue-was-opened', who: 10, name: 'user0', stale: 'who')
      .with(where: 'github', name: 'user1')
      .with(where: 'gitlab', who: 12, name: 'user2')
      .with(where: 'github', who: 13, name: 'user3', is_human: 1)
      .with(where: 'github', who: 14, name: 'my_bot', is_human: 0)
      .with(where: 'github', what: 'issue-was-opened', who: 15, name: 'rultor')
      .with(where: 'github', what: 'issue-was-opened', who: 16, name: '0pdd')
      .with(where: 'github', what: 'issue-was-opened', who: 17, name: 'other_bot')
      .with(where: 'github', what: 'issue-was-opened', who: 18, name: 'user4')
    load_it('is-human-or-robot', fb, Judges::Options.new({ 'bots' => '0pdd,rultor' }))
    assert_equal(9, fb.all.size)
    assert_equal(2, fb.picks(is_human: 1).size)
    assert_equal(4, fb.picks(is_human: 0).size)
    assert(fb.one?(where: 'github', who: 10, name: 'user0', stale: 'who'))
    assert(fb.one?(where: 'github', name: 'user1'))
    assert(fb.one?(where: 'gitlab', who: 12, name: 'user2'))
    assert(fb.one?(where: 'github', who: 15, name: 'rultor', is_human: 0))
    assert(fb.one?(where: 'github', who: 16, name: '0pdd', is_human: 0))
    assert(fb.one?(where: 'github', who: 17, name: 'other_bot', is_human: 0))
    assert(fb.one?(where: 'github', who: 18, name: 'user4', is_human: 1))
  end
end
