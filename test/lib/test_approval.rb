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

  def test_answers_nil_for_no_reviews
    assert_nil(Jp.approval([], nil))
  end
end
