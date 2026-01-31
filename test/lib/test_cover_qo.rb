# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
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
    now = Time.parse('2025-01-30 12:00:00 UTC')
    f1 = fb.insert
    f1.what = 'test-judge'
    f1.since = Time.parse('2025-01-01 12:00:00 UTC')
    f1.when = Time.parse('2025-01-05 12:00:00 UTC')
    f2 = fb.insert
    f2.what = 'test-judge'
    f2.since = Time.parse('2025-01-20 12:00:00 UTC')
    f2.when = Time.parse('2025-01-30 12:00:00 UTC')
    Fbe.stub(:fb, fb) do
      Jp.cover_qo(10, judge: 'test-judge', loog: Loog::NULL, today: now)
      facts = fb.query("(eq what 'test-judge')").each.to_a.sort_by(&:since)
      assert_equal(3, facts.size, 'gap fact inserted between two facts')
      gap = facts[1]
      assert_equal(Time.parse('2025-01-05 12:00:00 UTC').to_i, gap.since.to_i)
      assert_equal(Time.parse('2025-01-20 12:00:00 UTC').to_i, gap.when.to_i)
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
    now = Time.parse('2025-03-01 12:00:00 UTC')
    f1 = fb.insert
    f1.what = 'test-judge'
    f1.since = Time.parse('2025-01-01 12:00:00 UTC')
    f1.when = Time.parse('2025-01-05 12:00:00 UTC')
    f2 = fb.insert
    f2.what = 'test-judge'
    f2.since = Time.parse('2025-01-20 12:00:00 UTC')
    f2.when = Time.parse('2025-01-25 12:00:00 UTC')
    f3 = fb.insert
    f3.what = 'test-judge'
    f3.since = Time.parse('2025-02-15 12:00:00 UTC')
    f3.when = Time.parse('2025-03-01 12:00:00 UTC')
    Fbe.stub(:fb, fb) do
      Jp.cover_qo(10, judge: 'test-judge', loog: Loog::NULL, today: now)
      facts = fb.query("(eq what 'test-judge')").each.to_a.sort_by(&:since)
      assert_equal(5, facts.size, 'two gap facts inserted for two gaps')
      assert_equal(Time.parse('2025-01-05 12:00:00 UTC').to_i, facts[1].since.to_i)
      assert_equal(Time.parse('2025-01-20 12:00:00 UTC').to_i, facts[1].when.to_i)
      assert_equal(Time.parse('2025-01-25 12:00:00 UTC').to_i, facts[3].since.to_i)
      assert_equal(Time.parse('2025-02-15 12:00:00 UTC').to_i, facts[3].when.to_i)
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

  def test_does_not_add_when_single_fact_is_recent
    fb = Factbase.new
    now = Time.parse('2025-01-20 12:00:00 UTC')
    slice = 10 * 24 * 60 * 60
    f = fb.insert
    f.what = 'test-judge'
    f.since = now - slice
    f.when = now
    Fbe.stub(:fb, fb) do
      Jp.cover_qo(10, judge: 'test-judge', loog: Loog::NULL, today: now)
      facts = fb.query("(eq what 'test-judge')").each.to_a
      assert_equal(1, facts.size, 'no fact added when single fact covers current period')
    end
  end

  def test_handles_overlapping_facts_without_duplicate_gaps
    fb = Factbase.new
    now = Time.parse('2025-01-25 12:00:00 UTC')
    f1 = fb.insert
    f1.what = 'test-judge'
    f1.since = Time.parse('2025-01-01 12:00:00 UTC')
    f1.when = Time.parse('2025-01-15 12:00:00 UTC')
    f2 = fb.insert
    f2.what = 'test-judge'
    f2.since = Time.parse('2025-01-10 12:00:00 UTC')
    f2.when = Time.parse('2025-01-25 12:00:00 UTC')
    Fbe.stub(:fb, fb) do
      Jp.cover_qo(10, judge: 'test-judge', loog: Loog::NULL, today: now)
      facts = fb.query("(eq what 'test-judge')").each.to_a
      assert_equal(2, facts.size, 'no gap inserted when facts overlap')
    end
  end

  def test_sorts_facts_correctly_when_inserted_out_of_order
    fb = Factbase.new
    now = Time.parse('2025-01-30 12:00:00 UTC')
    f2 = fb.insert
    f2.what = 'test-judge'
    f2.since = Time.parse('2025-01-20 12:00:00 UTC')
    f2.when = Time.parse('2025-01-30 12:00:00 UTC')
    f1 = fb.insert
    f1.what = 'test-judge'
    f1.since = Time.parse('2025-01-01 12:00:00 UTC')
    f1.when = Time.parse('2025-01-05 12:00:00 UTC')
    Fbe.stub(:fb, fb) do
      Jp.cover_qo(10, judge: 'test-judge', loog: Loog::NULL, today: now)
      facts = fb.query("(eq what 'test-judge')").each.to_a.sort_by(&:since)
      assert_equal(3, facts.size, 'gap filled even when facts inserted out of order')
      assert_equal(Time.parse('2025-01-05 12:00:00 UTC').to_i, facts[1].since.to_i)
      assert_equal(Time.parse('2025-01-20 12:00:00 UTC').to_i, facts[1].when.to_i)
    end
  end

  def test_skips_gap_when_covered_by_overlapping_fact
    fb = Factbase.new
    now = Time.parse('2025-01-30 12:00:00 UTC')
    f1 = fb.insert
    f1.what = 'test-judge'
    f1.since = Time.parse('2025-01-01 12:00:00 UTC')
    f1.when = Time.parse('2025-01-05 12:00:00 UTC')
    f2 = fb.insert
    f2.what = 'test-judge'
    f2.since = Time.parse('2025-01-03 12:00:00 UTC')
    f2.when = Time.parse('2025-01-20 12:00:00 UTC')
    f3 = fb.insert
    f3.what = 'test-judge'
    f3.since = Time.parse('2025-01-15 12:00:00 UTC')
    f3.when = Time.parse('2025-01-30 12:00:00 UTC')
    Fbe.stub(:fb, fb) do
      Jp.cover_qo(10, judge: 'test-judge', loog: Loog::NULL, today: now)
      facts = fb.query("(eq what 'test-judge')").each.to_a
      assert_equal(3, facts.size, 'no gaps inserted when all covered by overlaps')
    end
  end

  def test_adds_fresh_fact_and_fills_historical_gaps
    fb = Factbase.new
    now = Time.parse('2025-02-15 12:00:00 UTC')
    slice = 10 * 24 * 60 * 60
    stale = now - slice - (5 * 24 * 60 * 60)
    f1 = fb.insert
    f1.what = 'test-judge'
    f1.since = Time.parse('2025-01-01 12:00:00 UTC')
    f1.when = Time.parse('2025-01-05 12:00:00 UTC')
    f2 = fb.insert
    f2.what = 'test-judge'
    f2.since = Time.parse('2025-01-20 12:00:00 UTC')
    f2.when = stale
    Fbe.stub(:fb, fb) do
      Jp.cover_qo(10, judge: 'test-judge', loog: Loog::NULL, today: now)
      facts = fb.query("(eq what 'test-judge')").each.to_a.sort_by(&:since)
      assert_equal(4, facts.size, 'fresh fact and historical gap both added')
      gap = facts.find { |f| f.since.to_i == Time.parse('2025-01-05 12:00:00 UTC').to_i }
      refute_nil(gap, 'historical gap fact not found')
      fresh = facts.find { |f| f.when.to_i == now.to_i }
      refute_nil(fresh, 'fresh fact not found')
    end
  end

  def test_uses_custom_today_parameter
    fb = Factbase.new
    custom = Time.parse('2025-03-15 12:00:00 UTC')
    slice = 10 * 24 * 60 * 60
    Fbe.stub(:fb, fb) do
      Jp.cover_qo(10, judge: 'test-judge', loog: Loog::NULL, today: custom)
      facts = fb.query("(eq what 'test-judge')").each.to_a
      assert_equal(1, facts.size, 'fact inserted with custom today')
      assert_equal(custom.to_i, facts.first.when.to_i)
      assert_equal((custom - slice).to_i, facts.first.since.to_i)
    end
  end

  def test_handles_unicode_judge_names
    fb = Factbase.new
    now = Time.parse('2025-01-20 12:00:00 UTC')
    name = 'судья-日本語-émoji-🔥'
    Fbe.stub(:fb, fb) do
      Jp.cover_qo(10, judge: name, loog: Loog::NULL, today: now)
      facts = fb.query("(eq what '#{name}')").each.to_a
      assert_equal(1, facts.size, 'fact inserted with unicode judge name')
      assert_equal(name, facts.first.what)
    end
  end

  def test_handles_zero_length_gap_at_boundary
    fb = Factbase.new
    now = Time.parse('2025-01-20 12:00:00 UTC')
    boundary = Time.parse('2025-01-10 12:00:00 UTC')
    f1 = fb.insert
    f1.what = 'test-judge'
    f1.since = Time.parse('2025-01-01 12:00:00 UTC')
    f1.when = boundary
    f2 = fb.insert
    f2.what = 'test-judge'
    f2.since = boundary
    f2.when = now
    Fbe.stub(:fb, fb) do
      Jp.cover_qo(10, judge: 'test-judge', loog: Loog::NULL, today: now)
      facts = fb.query("(eq what 'test-judge')").each.to_a
      assert_equal(2, facts.size, 'no gap inserted when facts meet at boundary')
    end
  end

  def test_handles_minimal_slice_of_one_day
    fb = Factbase.new
    now = Time.parse('2025-01-20 12:00:00 UTC')
    slice = 1 * 24 * 60 * 60
    Fbe.stub(:fb, fb) do
      Jp.cover_qo(1, judge: 'test-judge', loog: Loog::NULL, today: now)
      facts = fb.query("(eq what 'test-judge')").each.to_a
      assert_equal(1, facts.size, 'fact inserted with one-day slice')
      assert_equal((now - slice).to_i, facts.first.since.to_i)
    end
  end

  def test_does_not_add_when_fact_exactly_at_slice_boundary
    fb = Factbase.new
    now = Time.parse('2025-01-20 12:00:00 UTC')
    slice = 10 * 24 * 60 * 60
    boundary = now - slice
    f = fb.insert
    f.what = 'test-judge'
    f.since = boundary - slice
    f.when = boundary
    Fbe.stub(:fb, fb) do
      Jp.cover_qo(10, judge: 'test-judge', loog: Loog::NULL, today: now)
      facts = fb.query("(eq what 'test-judge')").each.to_a
      assert_equal(1, facts.size, 'no fresh fact when last is exactly at slice boundary')
    end
  end

  def test_adds_fresh_fact_when_just_past_slice_boundary
    fb = Factbase.new
    now = Time.parse('2025-01-20 12:00:00 UTC')
    slice = 10 * 24 * 60 * 60
    past = now - slice - 1
    f = fb.insert
    f.what = 'test-judge'
    f.since = past - slice
    f.when = past
    Fbe.stub(:fb, fb) do
      Jp.cover_qo(10, judge: 'test-judge', loog: Loog::NULL, today: now)
      facts = fb.query("(eq what 'test-judge')").each.to_a.sort_by(&:since)
      assert_equal(2, facts.size, 'fresh fact added when last is one second past boundary')
      assert_equal(past.to_i, facts.last.since.to_i)
      assert_equal(now.to_i, facts.last.when.to_i)
    end
  end

  def test_skips_many_small_gaps_below_slice
    fb = Factbase.new
    now = Time.parse('2025-01-30 12:00:00 UTC')
    base = Time.parse('2025-01-01 12:00:00 UTC')
    day = 24 * 60 * 60
    (0..9).each do |i|
      f = fb.insert
      f.what = 'test-judge'
      f.since = base + (i * 3 * day)
      f.when = base + (i * 3 * day) + day
    end
    Fbe.stub(:fb, fb) do
      Jp.cover_qo(10, judge: 'test-judge', loog: Loog::NULL, today: now)
      facts = fb.query("(eq what 'test-judge')").each.to_a
      assert_equal(10, facts.size, 'no small gaps filled when all are below slice')
    end
  end

  def test_does_not_insert_gap_when_fully_enclosed_by_larger_fact
    fb = Factbase.new
    now = Time.parse('2025-01-30 12:00:00 UTC')
    f1 = fb.insert
    f1.what = 'test-judge'
    f1.since = Time.parse('2025-01-01 12:00:00 UTC')
    f1.when = Time.parse('2025-01-05 12:00:00 UTC')
    f2 = fb.insert
    f2.what = 'test-judge'
    f2.since = Time.parse('2025-01-01 12:00:00 UTC')
    f2.when = Time.parse('2025-01-30 12:00:00 UTC')
    f3 = fb.insert
    f3.what = 'test-judge'
    f3.since = Time.parse('2025-01-20 12:00:00 UTC')
    f3.when = Time.parse('2025-01-30 12:00:00 UTC')
    Fbe.stub(:fb, fb) do
      Jp.cover_qo(10, judge: 'test-judge', loog: Loog::NULL, today: now)
      facts = fb.query("(eq what 'test-judge')").each.to_a
      assert_equal(3, facts.size, 'no gap inserted when enclosed by larger fact')
    end
  end

  def test_skips_gap_smaller_than_slice
    fb = Factbase.new
    now = Time.parse('2025-01-30 12:00:00 UTC')
    f1 = fb.insert
    f1.what = 'test-judge'
    f1.since = Time.parse('2025-01-01 12:00:00 UTC')
    f1.when = Time.parse('2025-01-10 12:00:00 UTC')
    f2 = fb.insert
    f2.what = 'test-judge'
    f2.since = Time.parse('2025-01-15 12:00:00 UTC')
    f2.when = Time.parse('2025-01-30 12:00:00 UTC')
    Fbe.stub(:fb, fb) do
      Jp.cover_qo(10, judge: 'test-judge', loog: Loog::NULL, today: now)
      facts = fb.query("(eq what 'test-judge')").each.to_a
      assert_equal(2, facts.size, 'gap of 5 days not filled when slice is 10 days')
    end
  end

  def test_fills_gap_equal_to_slice
    fb = Factbase.new
    now = Time.parse('2025-01-30 12:00:00 UTC')
    f1 = fb.insert
    f1.what = 'test-judge'
    f1.since = Time.parse('2025-01-01 12:00:00 UTC')
    f1.when = Time.parse('2025-01-10 12:00:00 UTC')
    f2 = fb.insert
    f2.what = 'test-judge'
    f2.since = Time.parse('2025-01-20 12:00:00 UTC')
    f2.when = Time.parse('2025-01-30 12:00:00 UTC')
    Fbe.stub(:fb, fb) do
      Jp.cover_qo(10, judge: 'test-judge', loog: Loog::NULL, today: now)
      facts = fb.query("(eq what 'test-judge')").each.to_a
      assert_equal(3, facts.size, 'gap of exactly 10 days filled when slice is 10 days')
    end
  end

  def test_fills_gap_larger_than_slice
    fb = Factbase.new
    now = Time.parse('2025-01-30 12:00:00 UTC')
    f1 = fb.insert
    f1.what = 'test-judge'
    f1.since = Time.parse('2025-01-01 12:00:00 UTC')
    f1.when = Time.parse('2025-01-05 12:00:00 UTC')
    f2 = fb.insert
    f2.what = 'test-judge'
    f2.since = Time.parse('2025-01-25 12:00:00 UTC')
    f2.when = Time.parse('2025-01-30 12:00:00 UTC')
    Fbe.stub(:fb, fb) do
      Jp.cover_qo(10, judge: 'test-judge', loog: Loog::NULL, today: now)
      facts = fb.query("(eq what 'test-judge')").each.to_a
      assert_equal(3, facts.size, 'gap of 20 days filled when slice is 10 days')
    end
  end
end
