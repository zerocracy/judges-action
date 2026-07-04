# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'fbe/tombstone'
require 'loog'
require_relative '../../lib/issue_was_lost'
require_relative '../test__helper'

class TestIssueWasLost < Minitest::Test
  def test_marks_prior_fact_stale_and_returns_early
    fb = Factbase.new
    f = fb.insert
    f.where = 'github'
    f.repository = 42
    f.issue = 7
    f.what = 'pull-was-opened'
    Fbe.stub(:fb, fb) do
      $loog = Loog::NULL
      Jp.issue_was_lost('github', 42, 7)
      facts = fb.query("(and (eq where 'github') (eq repository 42) (eq issue 7))").each.to_a
      assert_equal(1, facts.size, 'no new issue-was-lost fact inserted when a pre-existing fact was upgraded')
      assert_equal('issue', facts.first.stale, 'pre-existing fact must carry stale = issue')
    end
  end

  def test_inserts_fresh_fact_when_none_exists
    fb = Factbase.new
    Fbe.stub(:fb, fb) do
      $loog = Loog::NULL
      Jp.issue_was_lost('github', 42, 99)
      lost = fb.query("(and (eq what 'issue-was-lost') (eq where 'github') (eq repository 42) (eq issue 99))").each.to_a
      assert_equal(1, lost.size, 'a fresh issue-was-lost fact must be inserted when no prior fact exists')
      assert_equal('issue', lost.first.stale, 'the fresh fact must carry stale = issue')
      refute_nil(lost.first.when, 'the fresh fact must carry a when timestamp')
      assert(Fbe::Tombstone.new(fb: fb).has?('github', 42, 99), 'issue must be buried in the tombstone')
    end
  end

  def test_graceful_on_second_call_for_same_issue
    fb = Factbase.new
    Fbe.stub(:fb, fb) do
      $loog = Loog::NULL
      Jp.issue_was_lost('github', 42, 123)
      Jp.issue_was_lost('github', 42, 123)
    end
  end

  def test_buries_issue_in_the_tombstone
    fb = Factbase.new
    Fbe.stub(:fb, fb) do
      $loog = Loog::NULL
      refute(Fbe::Tombstone.new(fb: fb).has?('github', 7, 11), 'tombstone must be empty before the call')
      Jp.issue_was_lost('github', 7, 11)
      assert(Fbe::Tombstone.new(fb: fb).has?('github', 7, 11), 'tombstone must contain the issue after the call')
    end
  end
end
