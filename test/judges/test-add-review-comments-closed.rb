# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../test__helper'

class TestAddReviewCommentsClosed < Jp::Test
  def test_fills_review_comments_of_a_closed_pull
    WebMock.disable_net_connect!
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/93',
      body: {
        default_branch: 'master', additions: 1, deletions: 1,
        comments: 1, review_comments: 2, commits: 2, changed_files: 3
      }
    )
    stub_github(
      'https://api.github.com/repositories/42',
      body: { id: 820_463_873, name: 'foo', full_name: 'foo/foo' }
    )
    stub_github(
      'https://api.github.com/rate_limit',
      body: { rate: { limit: 600, remaining: 590, reset: 1_728_464_472, used: 1, resource: 'core' } }
    )
    fb = Factbase.new
    f = fb.insert
    f.what = 'pull-was-closed'
    f.issue = 93
    f.repository = 42
    f.where = 'github'
    load_it('add-review-comments', fb)
    assert_equal(
      2, fb.query('(eq what "pull-was-closed")').each.first.review_comments,
      'a pull that was closed without merging must get its review comments too'
    )
  end
end
