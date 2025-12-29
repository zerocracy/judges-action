# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'loog'
require 'minitest/mock'
require_relative '../../lib/cover_qo'
require_relative '../test__helper'

# Test for cover_qo method.
class TestCoverQo < Minitest::Test
  def test_inserts_first_fact_when_none_exist
    fb = Factbase.new
    Fbe.stub(:fb, fb) do
      now = Time.now
      Time.stub(:now, now) do
        Jp.cover_qo(10, judge: 'test-judge', loog: Loog::NULL)
      end
      facts = fb.query("(eq what 'test-judge')").each.to_a
      assert_equal(1, facts.size, 'exactly one fact inserted when none exist')
      assert_equal('test-judge', facts.first.what)
      assert_equal(now.to_i, facts.first.when.to_i)
      assert_equal((now - (10 * 24 * 60 * 60)).to_i, facts.first.since.to_i)
    end
  end

  def test_adds_fresh_fact_when_last_is_stale
    fb = Factbase.new
    now = Time.parse('2025-01-20 12:00:00 UTC')
    slice = 10 * 24 * 60 * 60
    old = now - slice - 1
    f = fb.insert
    f.what = 'test-judge'
    f.since = old - slice
    f.when = old
    Fbe.stub(:fb, fb) do
      Time.stub(:now, now) do
        Jp.cover_qo(10, judge: 'test-judge', loog: Loog::NULL)
      end
      facts = fb.query("(eq what 'test-judge')").each.to_a.sort_by(&:since)
      assert_equal(2, facts.size, 'fresh fact added when last is stale')
      assert_equal(old.to_i, facts.last.since.to_i)
      assert_equal(now.to_i, facts.last.when.to_i)
    end
  end

  def test_fills_gap_between_two_facts
    fb = Factbase.new
    now = Time.parse('2025-01-20 12:00:00 UTC')
    f1 = fb.insert
    f1.what = 'test-judge'
    f1.since = Time.parse('2025-01-01 12:00:00 UTC')
    f1.when = Time.parse('2025-01-10 12:00:00 UTC')
    f2 = fb.insert
    f2.what = 'test-judge'
    f2.since = Time.parse('2025-01-15 12:00:00 UTC')
    f2.when = Time.parse('2025-01-20 12:00:00 UTC')
    Fbe.stub(:fb, fb) do
      Time.stub(:now, now) do
        Jp.cover_qo(10, judge: 'test-judge', loog: Loog::NULL)
      end
      facts = fb.query("(eq what 'test-judge')").each.to_a.sort_by(&:since)
      assert_equal(3, facts.size, 'gap fact inserted between two facts')
      gap = facts[1]
      assert_equal(Time.parse('2025-01-10 12:00:00 UTC').to_i, gap.since.to_i)
      assert_equal(Time.parse('2025-01-15 12:00:00 UTC').to_i, gap.when.to_i)
    end
  end

  def test_does_not_add_when_facts_are_contiguous
    fb = Factbase.new
    now = Time.parse('2025-01-20 12:00:00 UTC')
    f1 = fb.insert
    f1.what = 'test-judge'
    f1.since = Time.parse('2025-01-01 12:00:00 UTC')
    f1.when = Time.parse('2025-01-10 12:00:00 UTC')
    f2 = fb.insert
    f2.what = 'test-judge'
    f2.since = Time.parse('2025-01-10 12:00:00 UTC')
    f2.when = Time.parse('2025-01-20 12:00:00 UTC')
    Fbe.stub(:fb, fb) do
      Time.stub(:now, now) do
        Jp.cover_qo(10, judge: 'test-judge', loog: Loog::NULL)
      end
      facts = fb.query("(eq what 'test-judge')").each.to_a
      assert_equal(2, facts.size, 'no new facts when timeline is contiguous')
    end
  end

  def test_fills_multiple_gaps
    fb = Factbase.new
    now = Time.parse('2025-01-30 12:00:00 UTC')
    f1 = fb.insert
    f1.what = 'test-judge'
    f1.since = Time.parse('2025-01-01 12:00:00 UTC')
    f1.when = Time.parse('2025-01-05 12:00:00 UTC')
    f2 = fb.insert
    f2.what = 'test-judge'
    f2.since = Time.parse('2025-01-10 12:00:00 UTC')
    f2.when = Time.parse('2025-01-15 12:00:00 UTC')
    f3 = fb.insert
    f3.what = 'test-judge'
    f3.since = Time.parse('2025-01-20 12:00:00 UTC')
    f3.when = Time.parse('2025-01-30 12:00:00 UTC')
    Fbe.stub(:fb, fb) do
      Time.stub(:now, now) do
        Jp.cover_qo(10, judge: 'test-judge', loog: Loog::NULL)
      end
      facts = fb.query("(eq what 'test-judge')").each.to_a.sort_by(&:since)
      assert_equal(5, facts.size, 'two gap facts inserted for two gaps')
      assert_equal(Time.parse('2025-01-05 12:00:00 UTC').to_i, facts[1].since.to_i)
      assert_equal(Time.parse('2025-01-10 12:00:00 UTC').to_i, facts[1].when.to_i)
      assert_equal(Time.parse('2025-01-15 12:00:00 UTC').to_i, facts[3].since.to_i)
      assert_equal(Time.parse('2025-01-20 12:00:00 UTC').to_i, facts[3].when.to_i)
    end
  end

  def test_ignores_facts_from_other_judges
    fb = Factbase.new
    now = Time.parse('2025-01-20 12:00:00 UTC')
    other = fb.insert
    other.what = 'other-judge'
    other.since = Time.parse('2025-01-01 12:00:00 UTC')
    other.when = Time.parse('2025-01-10 12:00:00 UTC')
    Fbe.stub(:fb, fb) do
      Time.stub(:now, now) do
        Jp.cover_qo(10, judge: 'test-judge', loog: Loog::NULL)
      end
      facts = fb.query("(eq what 'test-judge')").each.to_a
      assert_equal(1, facts.size, 'new fact inserted ignoring other judge')
      assert_equal('test-judge', facts.first.what)
    end
  end
end
