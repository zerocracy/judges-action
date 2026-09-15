# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'judges/options'
require 'loog'
require_relative '../../lib/pull_request'
require_relative '../test__helper'

class TestPullRequestSuggestions < Jp::Test
  def test_counts_no_suggestion_of_a_bot
    WebMock.disable_net_connect!
    rate_limit_up
    $options = Judges::Options.new({ 'bots' => 'namedbot' })
    $global = {}
    $loog = Loog::NULL
    reviews = [{ id: 10, user: { id: 100 } }]
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/1/reviews/10/comments?per_page=100',
      body: [
        { id: 1, user: { id: 100, login: 'reviewer', type: 'User' }, in_reply_to_id: nil },
        { id: 2, user: { id: 101, login: 'robot', type: 'Bot' }, in_reply_to_id: nil },
        { id: 3, user: { id: 102, login: 'namedbot', type: 'User' }, in_reply_to_id: nil }
      ]
    )
    assert_equal(
      1, Jp.count_suggestions('foo/foo', 1, 300, reviews),
      'neither a Bot account nor a configured bot login can count as a suggestion'
    )
  end
end
