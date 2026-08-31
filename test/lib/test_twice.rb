# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../../lib/twice'
require_relative '../test__helper'

class TestTwice < Minitest::Test
  def test_finds_the_second_copy_of_the_same_event
    fb = Factbase.new
    2.times { insert(fb, 'bug') }
    assert(
      Jp.twice?(fb, fb.query('(exists label)').each.to_a.first, 'label-was-attached', %w[where repository issue label]),
      'the second copy of the same event cannot stay unnoticed'
    )
  end

  def test_lets_a_unique_event_through
    fb = Factbase.new
    insert(fb, 'bug')
    refute(
      Jp.twice?(fb, fb.query('(exists label)').each.to_a.first, 'label-was-attached', %w[where repository issue label]),
      'a unique event cannot be taken for a duplicate'
    )
  end

  def test_finds_the_second_copy_when_the_label_has_an_apostrophe
    fb = Factbase.new
    2.times { insert(fb, "won't fix") }
    assert(
      Jp.twice?(fb, fb.query('(exists label)').each.to_a.first, 'label-was-attached', %w[where repository issue label]),
      'an apostrophe in a label cannot hide a duplicate'
    )
  end

  def test_finds_the_second_copy_when_the_label_ends_with_a_backslash
    fb = Factbase.new
    2.times { insert(fb, 'fix\\') }
    assert(
      Jp.twice?(fb, fb.query('(exists label)').each.to_a.first, 'label-was-attached', %w[where repository issue label]),
      'a backslash in a label cannot hide a duplicate'
    )
  end

  def test_reads_a_label_that_looks_like_a_query_as_plain_text
    fb = Factbase.new
    2.times { insert(fb, "x') (eq issue 999) (eq label 'y") }
    assert(
      Jp.twice?(fb, fb.query('(exists label)').each.to_a.first, 'label-was-attached', %w[where repository issue label]),
      'a label that looks like a query cannot be read as one'
    )
  end

  def test_ignores_the_events_of_another_repository
    fb = Factbase.new
    insert(fb, 'bug')
    insert(fb, 'bug', repository: 55)
    refute(
      Jp.twice?(
        fb, fb.query('(eq repository 42)').each.to_a.first, 'label-was-attached', %w[where repository issue label]
      ),
      'events of another repository cannot count as duplicates'
    )
  end

  private

  def insert(fb, label, repository: 42)
    f = fb.insert
    f.what = 'label-was-attached'
    f.where = 'github'
    f.repository = repository
    f.issue = 7
    f.label = label
    f
  end
end
