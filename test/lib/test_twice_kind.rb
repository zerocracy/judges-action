# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../../lib/twice'
require_relative '../test__helper'

class TestTwiceKind < Minitest::Test
  def test_lets_a_fact_of_another_kind_through
    fb = Factbase.new
    2.times do
      f = fb.insert
      f.what = 'issue-was-opened'
      f.where = 'github'
      f.repository = 42
      f.issue = 7
    end
    fresh = fb.insert
    fresh.what = 'issue-was-closed'
    fresh.where = 'github'
    fresh.repository = 42
    fresh.issue = 7
    refute(
      Jp.twice?(fb, fresh, 'issue-was-opened', %w[where repository issue]),
      'a rule of another kind cannot roll back this event'
    )
  end
end
