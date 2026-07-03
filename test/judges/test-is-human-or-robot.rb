# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'octokit'
require_relative '../test__helper'

class TestIsHumanOrRobot < Jp::Test
  using SmartFactbase

  def test_handles_missing_github_user_gracefully
    id = 444
    fb = Factbase.new
    fact = fb.insert
    fact.who = id
    fact.where = 'github'
    VCR.use_cassette('is-human-or-robot/handles-missing-github-user-gracefully') do
      load_it('is-human-or-robot', fb)
    end
    facts = fb.query("(eq who #{id})").each.to_a
    assert_equal(id, facts.first.who)
    assert_equal(
      "Can't find 'is_human' attribute out of [who, where]",
      assert_raises(ArgumentError) { facts.first.is_human }.message
    )
  end

  def test_identify_user_as_bot_or_human
    rate_limit_up
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
    VCR.use_cassette('is-human-or-robot/identify-user-as-bot-or-human') do
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

  def test_marks_fact_stale_on_forbidden_user_lookup
    rate_limit_up
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-merged', repository: 42, issue: 44, who: 29_139_614, where: 'github')
    VCR.use_cassette('is-human-or-robot/marks-fact-stale-on-forbidden-user-lookup') do
      load_it('is-human-or-robot', fb)
    end
    fact = fb.query('(eq who 29139614)').each.first
    refute_nil(fact)
    assert_equal(
      "Can't find 'stale' attribute out of [_id, what, repository, issue, who, where]",
      assert_raises(ArgumentError) { fact.stale }.message,
      'fact should not be marked stale on transient 403 so the next cycle can retry'
    )
    assert_equal(
      "Can't find 'is_human' attribute out of [_id, what, repository, issue, who, where]",
      assert_raises(ArgumentError) { fact.is_human }.message,
      'is_human should remain absent when the 403 prevented classification'
    )
  end

  def test_one_forbidden_user_does_not_abort_other_users
    rate_limit_up
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-merged', who: 100, where: 'github')
      .with(_id: 2, what: 'pull-was-merged', who: 200, where: 'github')
      .with(_id: 3, what: 'pull-was-merged', who: 300, where: 'github')
    VCR.use_cassette('is-human-or-robot/one-forbidden-user-does-not-abort-other-users') do
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
    assert_equal(
      "Can't find 'is_human' attribute out of [_id, what, who, where]",
      assert_raises(ArgumentError) { forbidden.is_human }.message,
      'the 403 user should remain unclassified, ready for a retry'
    )
  end
end
