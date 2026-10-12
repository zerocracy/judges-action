# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'judges/options'
require_relative '../test__helper'

class TestCodeWasReviewedCount < Jp::Test
  using SmartFactbase

  def test_counts_reviewers_not_submissions
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, full_name: 'foo/foo' })
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/44',
      body: {
        number: 44, user: { id: 411 }, additions: 1, deletions: 1,
        created_at: Time.parse('2025-05-01 09:00:00 UTC')
      }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/44/reviews?per_page=100',
      body: [
        { id: 1, user: { id: 500, login: 'rev', type: 'User' }, submitted_at: Time.parse('2025-05-01 10:00:00 UTC') },
        { id: 2, user: { id: 500, login: 'rev', type: 'User' }, submitted_at: Time.parse('2025-05-01 11:00:00 UTC') },
        { id: 3, user: { id: 411, login: 'auth', type: 'User' }, submitted_at: Time.parse('2025-05-01 12:00:00 UTC') },
        { id: 4, user: { id: 900, login: 'bot', type: 'Bot' }, submitted_at: Time.parse('2025-05-01 13:00:00 UTC') }
      ]
    )
    stub_github('https://api.github.com/repos/foo/foo/issues/44/comments?per_page=100', body: [])
    (1..4).each do |rid|
      stub_github("https://api.github.com/repos/foo/foo/pulls/44/reviews/#{rid}/comments?per_page=100", body: [])
    end
    stub_github('https://api.github.com/repos/foo/foo/pulls/44/comments?per_page=100', body: [])
    stub_github('https://api.github.com/user/500', body: { id: 500, login: 'rev' })
    stub_github('https://api.github.com/user/411', body: { id: 411, login: 'auth' })
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-merged', repository: 42, issue: 44, where: 'github')
    load_it('code-was-reviewed', fb)
    assert_equal(
      1, fb.pick(what: 'pull-was-merged', issue: 44).reviews,
      'the count must match the facts the judge creates, one per distinct human reviewer'
    )
  end
end
