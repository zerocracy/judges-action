# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../../lib/twice'
require_relative '../test__helper'

class TestTwice < Jp::Test
  def test_apostrophe_in_label_is_escaped
    fb = Factbase.new
    fb.insert.then do |f|
      f.what = 'label-was-attached'
      f.where = 'github'
      f.repository = 42
      f.issue = 1
      f.label = "O'Brien"
    end
    fact = fb.query('(eq what "label-was-attached")').each.first
    refute(Jp.twice?(fb, fact, 'label-was-attached', %w[where repository issue label]))
  end

  def test_apostrophe_in_label_detects_duplicate
    fb = Factbase.new
    2.times do
      fb.insert.then do |f|
        f.what = 'label-was-attached'
        f.where = 'github'
        f.repository = 42
        f.issue = 1
        f.label = "O'Brien"
      end
    end
    fact = fb.query('(eq what "label-was-attached")').each.first
    assert(Jp.twice?(fb, fact, 'label-was-attached', %w[where repository issue label]))
  end
end
