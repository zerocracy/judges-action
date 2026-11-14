# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'judges/options'
require 'loog'
require 'webmock'
require_relative '../../lib/pull_request'
require_relative '../test__helper'

class TestPullRequestSuggestions < Jp::Test
  def test_counts_the_comment_that_suggests_a_change
    WebMock.disable_net_connect!
    rate_limit_up
    $options = Judges::Options.new({})
    $global = {}
    $loog = Loog::NULL
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/77/reviews/1/comments?per_page=100',
      body: [
        { id: 900, user: { id: 2 }, in_reply_to_id: nil, body: 'Looks good, nice change!' },
        { id: 901, user: { id: 2 }, in_reply_to_id: nil, body: "Try this:\n```suggestion\nx = 1\n```" }
      ]
    )
    count = Jp.count_suggestions('foo/foo', 77, 1, [{ id: 1, user: { id: 2 } }])
    assert_equal(1, count)
  end

  def test_count_suggestions_returns_zero_when_reviews_are_not_found
    WebMock.disable_net_connect!
    rate_limit_up
    $options = Judges::Options.new({})
    $global = {}
    $loog = Loog::NULL
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/77/reviews?per_page=100',
      status: 404,
      body: { message: 'Not Found' }
    )
    count = Jp.count_suggestions('foo/foo', 77, 1)
    assert_equal(0, count)
  end

  def test_count_suggestions_returns_zero_when_reviews_are_deprecated
    WebMock.disable_net_connect!
    rate_limit_up
    $options = Judges::Options.new({})
    $global = {}
    $loog = Loog::NULL
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/77/reviews?per_page=100',
      status: 410,
      body: { message: 'Gone' }
    )
    count = Jp.count_suggestions('foo/foo', 77, 1)
    assert_equal(0, count)
  end

  def test_count_suggestions_returns_zero_when_reviews_are_forbidden
    WebMock.disable_net_connect!
    rate_limit_up
    $options = Judges::Options.new({})
    $global = {}
    $loog = Loog::NULL
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/77/reviews?per_page=100',
      status: 403,
      body: { message: 'Resource not accessible by integration' }
    )
    count = Jp.count_suggestions('foo/foo', 77, 1)
    assert_equal(0, count)
  end

  def test_count_suggestions_keeps_the_next_review_when_comments_are_forbidden
    WebMock.disable_net_connect!
    rate_limit_up
    $options = Judges::Options.new({})
    $global = {}
    $loog = Loog::NULL
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/77/reviews/1/comments?per_page=100',
      status: 403,
      body: { message: 'Resource not accessible by integration' }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/77/reviews/2/comments?per_page=100',
      body: [
        { id: 900, user: { id: 3 }, in_reply_to_id: nil, body: "Try this:\n```suggestion\nx = 1\n```" }
      ]
    )
    count = Jp.count_suggestions('foo/foo', 77, 1, [{ id: 1, user: { id: 2 } }, { id: 2, user: { id: 3 } }])
    assert_equal(1, count)
  end

  def test_count_suggestions_keeps_the_next_review_when_comments_are_not_found
    WebMock.disable_net_connect!
    rate_limit_up
    $options = Judges::Options.new({})
    $global = {}
    $loog = Loog::NULL
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/77/reviews/1/comments?per_page=100',
      status: 404,
      body: { message: 'Not Found' }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/77/reviews/2/comments?per_page=100',
      body: [
        { id: 900, user: { id: 3 }, in_reply_to_id: nil, body: "Try this:\n```suggestion\nx = 1\n```" }
      ]
    )
    count = Jp.count_suggestions('foo/foo', 77, 1, [{ id: 1, user: { id: 2 } }, { id: 2, user: { id: 3 } }])
    assert_equal(1, count)
  end

  def test_count_suggestions_keeps_the_next_review_when_comments_are_deprecated
    WebMock.disable_net_connect!
    rate_limit_up
    $options = Judges::Options.new({})
    $global = {}
    $loog = Loog::NULL
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/77/reviews/1/comments?per_page=100',
      status: 410,
      body: { message: 'Gone' }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/77/reviews/2/comments?per_page=100',
      body: [
        { id: 900, user: { id: 3 }, in_reply_to_id: nil, body: "Try this:\n```suggestion\nx = 1\n```" }
      ]
    )
    count = Jp.count_suggestions('foo/foo', 77, 1, [{ id: 1, user: { id: 2 } }, { id: 2, user: { id: 3 } }])
    assert_equal(1, count)
  end
end
