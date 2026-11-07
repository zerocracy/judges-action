# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'time'
require_relative '../../lib/approval'
require_relative '../test__helper'

class TestApproval < Minitest::Test
  def test_takes_the_last_approval
    reviews = [
      { state: 'CHANGES_REQUESTED', submitted_at: Time.parse('2025-06-20 10:00:00 UTC') },
      { state: 'APPROVED', submitted_at: Time.parse('2025-06-27 18:00:00 UTC') }
    ]
    assert_equal(
      Time.parse('2025-06-27 18:00:00 UTC'),
      Jp.approval(reviews, Time.parse('2025-06-27 19:00:05 UTC'))[:submitted_at]
    )
  end

  def test_skips_an_approval_after_the_pull_was_closed
    reviews = [
      { state: 'APPROVED', submitted_at: Time.parse('2025-06-21 10:00:00 UTC') },
      { state: 'APPROVED', submitted_at: Time.parse('2025-07-01 10:00:00 UTC') }
    ]
    assert_equal(
      Time.parse('2025-06-21 10:00:00 UTC'),
      Jp.approval(reviews, Time.parse('2025-06-27 19:00:05 UTC'))[:submitted_at]
    )
  end

  def test_takes_the_last_review_when_nothing_was_approved
    reviews = [
      { state: 'CHANGES_REQUESTED', submitted_at: Time.parse('2025-06-20 10:00:00 UTC') },
      { state: 'COMMENTED', submitted_at: Time.parse('2025-06-25 10:00:00 UTC') }
    ]
    assert_equal(Time.parse('2025-06-25 10:00:00 UTC'), Jp.approval(reviews, nil)[:submitted_at])
  end

  def test_answers_nil_when_every_review_came_after_the_closure
    reviews = [
      { state: 'APPROVED', submitted_at: Time.parse('2025-07-01 10:00:00 UTC') },
      { state: 'COMMENTED', submitted_at: Time.parse('2025-07-02 10:00:00 UTC') }
    ]
    assert_nil(Jp.approval(reviews, Time.parse('2025-06-27 19:00:05 UTC')))
  end

  def test_answers_nil_for_no_reviews
    assert_nil(Jp.approval([], nil))
  end

  def test_ignores_a_review_written_by_the_pull_author
    author = { id: 1, type: 'User' }
    reviews = [{ state: 'COMMENTED', user: author, submitted_at: Time.parse('2025-06-20 10:00:00 UTC') }]
    assert_nil(Jp.approval(reviews, Time.parse('2025-06-27 19:00:05 UTC'), author[:id]))
  end

  def test_ignores_a_review_written_by_a_bot
    bot = { id: 9, type: 'Bot', login: 'copilot' }
    reviews = [{ state: 'APPROVED', user: bot, submitted_at: Time.parse('2025-06-21 10:00:00 UTC') }]
    assert_nil(Jp.approval(reviews, Time.parse('2025-06-27 19:00:05 UTC'), 1))
  end

  def test_takes_a_human_approval_and_ignores_the_author_and_bots
    author = { id: 1, type: 'User' }
    bot = { id: 9, type: 'Bot', login: 'copilot' }
    human = { state: 'APPROVED', user: { id: 2, type: 'User' }, submitted_at: Time.parse('2025-06-22 10:00:00 UTC') }
    reviews = [
      { state: 'COMMENTED', user: author, submitted_at: Time.parse('2025-06-20 10:00:00 UTC') },
      { state: 'APPROVED', user: bot, submitted_at: Time.parse('2025-06-21 10:00:00 UTC') },
      human
    ]
    assert_equal(human, Jp.approval(reviews, Time.parse('2025-06-27 19:00:05 UTC'), author[:id]))
  end

  def test_keeps_a_human_comment_when_only_a_bot_approved
    human = { state: 'COMMENTED', user: { id: 2, type: 'User' }, submitted_at: Time.parse('2025-06-19 10:00:00 UTC') }
    bot = {
      state: 'APPROVED', user: { id: 9, type: 'Bot', login: 'copilot' },
      submitted_at: Time.parse('2025-06-21 10:00:00 UTC')
    }
    assert_equal(human, Jp.approval([human, bot], Time.parse('2025-06-27 19:00:05 UTC'), 1))
  end
end
