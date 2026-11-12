# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../test__helper'

class TestUserClassificationCache < Jp::Test
  using SmartFactbase

  def test_looks_up_each_distinct_user_once
    classify
    assert_requested(:get, 'https://api.github.com/user/42', times: 1)
  end

  def test_classifies_every_fact_of_the_user
    assert_equal(5, classify.picks(who: 42, is_human: 1).size, 'every fact of the human must be classified')
  end

  def test_keeps_distinct_user_classifications
    assert_equal(1, classify.picks(who: 43, is_human: 0).size, 'the other user must keep its bot classification')
  end

  def test_caches_missing_user_responses_for_the_run
    classify(status: 404)
    assert_requested(:get, 'https://api.github.com/user/42', times: 1)
  end

  def test_marks_every_fact_of_the_missing_user_stale
    assert_equal(5, classify(status: 404).picks(who: 42, stale: 'who').size)
  end

  def test_caches_forbidden_user_responses_for_the_run
    classify(status: 403)
    assert_requested(:get, 'https://api.github.com/user/42', times: 1)
  end

  def test_retries_forbidden_users_on_the_next_run
    fb = classify(status: 403)
    stub_github('https://api.github.com/user/42', body: { id: 42, login: 'alice', type: 'User' })
    load_it('is-human-or-robot', fb)
    assert_equal(5, fb.picks(who: 42, is_human: 1).size, 'a later run must recover every inaccessible fact')
  end

  def test_does_not_look_up_repositories_for_log_messages
    classify
    assert_not_requested(:get, 'https://api.github.com/repositories/15')
  end

  private

  def classify(status: 200)
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/user/42', status:, body: { id: 42, login: 'alice', type: 'User' })
    stub_github('https://api.github.com/user/43', body: { id: 43, login: 'robot', type: 'Bot' })
    fb = Factbase.new
    5.times do |index|
      fb.with(what: 'issue-was-opened', who: 42, repository: 15, issue: index + 1, where: 'github')
    end
    fb.with(what: 'issue-was-opened', who: 43, repository: 15, issue: 6, where: 'github')
    load_it('is-human-or-robot', fb)
    fb
  end
end
