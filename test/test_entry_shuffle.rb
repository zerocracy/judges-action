# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative 'test__helper'

class TestEntryShuffle < Jp::Test
  def test_gives_the_shuffle_a_seed_and_a_prefix_that_exists
    root = File.expand_path('..', __dir__)
    body = File.read(File.join(root, 'entry.sh'))
    shuffle = body[/--shuffle=(\S+)/, 1]
    refute_nil(shuffle, 'entry.sh must ask for a shuffle')
    assert_match(/--seed=/, body, 'a shuffle without a seed repeats the same order on every run')
    assert_path_exists(
      File.join(root, 'judges', shuffle),
      "the shuffle prefix #{shuffle.inspect} matches no judge, so it leaves nothing unshuffled"
    )
  end
end
