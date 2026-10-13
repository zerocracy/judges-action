# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative '../../lib/labeled'
require_relative '../test__helper'

class TestLabeled < Minitest::Test
  def test_keeps_label_attached_again_after_removal
    events = %w[labeled unlabeled labeled].each_with_index.map { |e, i| { id: i, event: e, label: { name: 'баг' } } }
    assert_equal([2], Jp.labeled(events).map { |e| e[:id] }, 'a label attached again is not the last attachment')
  end

  def test_keeps_label_when_another_one_is_removed
    events = [
      { id: 1, event: 'labeled', label: { name: 'bug' } },
      { id: 2, event: 'unlabeled', label: { name: 'question' } }
    ]
    assert_equal([1], Jp.labeled(events).map { |e| e[:id] }, 'removing one label drops another')
  end
end
