# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'loog'
require_relative '../../lib/patches/fake_octokit'
require_relative '../test__helper'

class TestFakeOctokit < Jp::Test
  def test_lists_milestones_of_a_repository
    $global = {}
    $options = Judges::Options.new({ 'testing' => true })
    $loog = Loog::NULL
    assert_empty(
      Fbe.octo.list_milestones('foo/foo', state: 'all'),
      'The milestones stub cannot refuse the options that judges send with it'
    )
  end

  def test_counts_forks_of_a_repository
    $global = {}
    $options = Judges::Options.new({ 'testing' => true })
    $loog = Loog::NULL
    seed = Random.new_seed
    repo = "foo/проект-#{Random.new(seed).rand(1..999_999)}"
    assert_predicate(
      Fbe.octo.repository(repo)[:forks],
      :positive?,
      "The repository stub reports no forks for #{repo}, the zero that a missing count falls back to (seed: #{seed})"
    )
  end

  def test_reports_same_forks_under_both_names
    $global = {}
    $options = Judges::Options.new({ 'testing' => true })
    $loog = Loog::NULL
    seed = Random.new_seed
    json = Fbe.octo.repository("bar/ünïcode-#{Random.new(seed).rand(1..999_999)}")
    assert_equal(
      json[:forks],
      json[:forks_count],
      "The repository stub reports forks that disagree with its forks_count for #{json[:full_name]} (seed: #{seed})"
    )
  end

  def test_cannot_find_missing_repository
    $global = {}
    $options = Judges::Options.new({ 'testing' => true })
    $loog = Loog::NULL
    seed = Random.new_seed
    id = [404_123, 404_124].sample(random: Random.new(seed))
    assert_raises(Octokit::NotFound, "The repository stub finds the missing repository #{id} (seed: #{seed})") do
      Fbe.octo.repository(id)
    end
  end
end
