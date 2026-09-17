# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'judges/options'
require 'loog'
require_relative '../test__helper'

class TestTotalActiveContributorsCap < Jp::Test
  def test_reports_nothing_when_the_page_is_full
    assert_empty(counted(100))
  end

  def test_counts_a_page_that_is_not_full
    assert_equal({ total_active_contributors: 7 }, counted(7))
  end

  private

  def counted(commits)
    $judge = 'dimensions-of-terrain'
    $loog = Loog::NULL
    $global = {}
    $options = Judges::Options.new({ 'repositories' => 'foo/foo' })
    fact = Factbase.new.insert
    fact.when = Time.parse('2025-02-01 00:00:00 UTC')
    found = { items: Array.new(commits) { |i| { author: { id: i + 1 } } } }
    load(File.join(__dir__, '../../judges/dimensions-of-terrain/total_active_contributors.rb'))
    Fbe.stub(:unmask_repos, proc { |&b| b.call('foo/foo') }) do
      Jp.stub(:qosearch, found) { total_active_contributors(fact) }
    end
  end
end
