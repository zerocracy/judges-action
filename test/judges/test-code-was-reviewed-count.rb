# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'judges/options'
require_relative '../fake_github'
require_relative '../test__helper'

class TestCodeWasReviewedCount < Jp::Test
  using SmartFactbase

  def test_counts_reviewers_not_submissions
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-merged', repository: 42, issue: 44, where: 'github')
    Jp::FakeGithub.new(
      'GET /rate_limit' => { resources: { search: { remaining: 30, limit: 30 } }, rate: { remaining: 1000 } },
      'GET /repos/foo/foo' => { id: 42, full_name: 'foo/foo' },
      'GET /repositories/42' => { id: 42, full_name: 'foo/foo' },
      'GET /repos/foo/foo/pulls/44' => {
        number: 44, user: { id: 411 }, additions: 1, deletions: 1,
        created_at: Time.parse('2025-05-01 09:00:00 UTC')
      },
      'GET /repos/foo/foo/pulls/44/reviews?per_page=100' => [
        { id: 1, user: { id: 500, login: 'rev', type: 'User' }, submitted_at: Time.parse('2025-05-01 10:00:00 UTC') },
        { id: 2, user: { id: 500, login: 'rev', type: 'User' }, submitted_at: Time.parse('2025-05-01 11:00:00 UTC') },
        { id: 3, user: { id: 411, login: 'auth', type: 'User' }, submitted_at: Time.parse('2025-05-01 12:00:00 UTC') },
        { id: 4, user: { id: 900, login: 'bot', type: 'Bot' }, submitted_at: Time.parse('2025-05-01 13:00:00 UTC') }
      ],
      'GET /repos/foo/foo/issues/44/comments?per_page=100' => [],
      'GET /repos/foo/foo/pulls/44/reviews/1/comments?per_page=100' => [],
      'GET /repos/foo/foo/pulls/44/reviews/2/comments?per_page=100' => [],
      'GET /repos/foo/foo/pulls/44/reviews/3/comments?per_page=100' => [],
      'GET /repos/foo/foo/pulls/44/reviews/4/comments?per_page=100' => [],
      'GET /repos/foo/foo/pulls/44/comments?per_page=100' => [],
      'GET /user/500' => { id: 500, login: 'rev' },
      'GET /user/411' => { id: 411, login: 'auth' }
    ).run do
      load_it('code-was-reviewed', fb)
    end
    assert_equal(
      1, fb.pick(what: 'pull-was-merged', issue: 44).reviews,
      'the count must match the facts the judge creates, one per distinct human reviewer'
    )
  end
end
