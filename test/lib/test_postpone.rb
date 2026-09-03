# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'loog'
require 'octokit'
require_relative '../../lib/postpone'
require_relative '../test__helper'

class TestPostpone < Minitest::Test
  def test_postponed_metric_is_empty
    seed = Random.new_seed
    repo = "фу/бар-#{Random.new(seed).rand(100_000)}"
    $loog = Loog::NULL
    $judge = 'dimensions-of-terrain'
    assert_empty(
      Jp.measured { Jp.postpone(repo, Octokit::Forbidden.new) },
      "the metric of #{repo} is not empty after postponing, seed #{seed}"
    )
  end
end
