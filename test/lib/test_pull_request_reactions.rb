# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'judges/options'
require 'loog'
require 'webmock'
require_relative '../../lib/pull_request'
require_relative '../test__helper'

class TestPullRequestReactions < Jp::Test
  def test_counts_only_the_positive_reactions
    WebMock.disable_net_connect!
    rate_limit_up
    $options = Judges::Options.new({})
    $global = {}
    $loog = Loog::NULL
    stub_github(
      'https://api.github.com/repos/foo/foo/issues/comments/101/reactions',
      body: [
        { user: { id: 42 }, content: '-1' },
        { user: { id: 43 }, content: 'confused' },
        { user: { id: 44 }, content: 'heart' }
      ]
    )
    count =
      Jp.count_appreciated_comments({ base: { repo: { full_name: 'foo/foo' } } }, [{ id: 101, user: { id: 7 } }], [])
    assert_equal(1, count)
  end
end
