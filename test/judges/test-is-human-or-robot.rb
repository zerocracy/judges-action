# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../fake_github'
require_relative '../test__helper'

class TestIsHumanOrRobot < Jp::Test
  using SmartFactbase

  def test_handles_missing_github_user_gracefully
    id = 444
    fb = Factbase.new
    fact = fb.insert
    fact.who = id
    fact.where = 'github'
    Jp::FakeGithub.new(
      'GET /rate_limit' => {
        rate: { limit: 60, remaining: 59, reset: 1_728_464_472, used: 1, resource: 'core' }
      },
      "GET /user/#{id}" => [404, {}]
    ).run do
      load_it('is-human-or-robot', fb)
    end
    facts = fb.query("(eq who #{id})").each.to_a
    assert_equal(id, facts.first.who)
    assert_raises(ArgumentError) { facts.first.is_human }
  end

  def test_identify_user_as_bot_or_human
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
    Jp::FakeGithub.new(
      'GET /rate_limit' => { resources: { search: { remaining: 30, limit: 30 } }, rate: { remaining: 1000 } },
      'GET /user/15' => { login: 'rultor', id: 15, type: 'User' },
      'GET /user/16' => { login: '0pdd', id: 16, type: 'User' },
      'GET /user/17' => { login: 'other_bot', id: 17, type: 'Bot' },
      'GET /user/18' => { login: 'user4', id: 18, type: 'User' }
    ).run do
      load_it('is-human-or-robot', fb, Judges::Options.new({ 'bots' => '0pdd,rultor' }))
    end
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

  def test_forbidden_user_lookup_leaves_fact_retriable
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-merged', repository: 42, issue: 44, who: 29_139_614, where: 'github')
    Jp::FakeGithub.new(
      'GET /rate_limit' => { resources: { search: { remaining: 30, limit: 30 } }, rate: { remaining: 1000 } },
      'GET /user/29139614' => [403, { message: 'Resource not accessible by integration' }]
    ).run do
      load_it('is-human-or-robot', fb)
    end
    fact = fb.query('(eq who 29139614)').each.first
    refute_nil(fact)
    assert_raises(ArgumentError, 'fact should not be marked stale on transient 403') { fact.stale }
    assert_raises(ArgumentError, 'is_human should remain absent when the 403 prevented classification') do
      fact.is_human
    end
  end

  def test_forbidden_user_does_not_abort_others
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-merged', who: 100, where: 'github')
      .with(_id: 2, what: 'pull-was-merged', who: 200, where: 'github')
      .with(_id: 3, what: 'pull-was-merged', who: 300, where: 'github')
    Jp::FakeGithub.new(
      'GET /rate_limit' => { resources: { search: { remaining: 30, limit: 30 } }, rate: { remaining: 1000 } },
      'GET /user/100' => { login: 'alice', id: 100, type: 'User' },
      'GET /user/200' => [403, { message: 'Resource not accessible by integration' }],
      'GET /user/300' => { login: 'bob', id: 300, type: 'User' }
    ).run do
      load_it('is-human-or-robot', fb)
    end
    classified = fb.query('(exists is_human)').each.to_a
    staled = fb.query("(eq stale 'who')").each.to_a
    assert_equal(2, classified.size, 'both good users (100, 300) should be classified')
    ids = classified.map(&:who)
    ids.sort!
    assert_equal([100, 300], ids, 'classified facts should be the two non-403 users')
    assert_equal(0, staled.size, 'the 403 user must not be marked stale so the next cycle can retry')
    forbidden = fb.query('(eq who 200)').each.first
    refute_nil(forbidden)
    assert_raises(ArgumentError, 'the 403 user should remain unclassified, ready for a retry') { forbidden.is_human }
  end
end
