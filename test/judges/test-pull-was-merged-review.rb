# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'fbe/github_graph'
require_relative '../test__helper'

class TestPullWasMergedReview < Jp::Test
  using SmartFactbase

  def test_ignores_a_self_review_when_marking_a_pull_reviewed
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, name: 'foo', full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/44',
      body: {
        id: 50, number: 44, user: { id: 421, login: 'user' }, state: 'closed',
        closed_at: Time.parse('2025-09-30 18:00:00 UTC'),
        closed_by: { login: 'user2', id: 422 },
        created_at: Time.parse('2025-09-30 15:35:30 UTC'),
        additions: 12, deletions: 5,
        head: { ref: '40', sha: 'aa123' },
        base: { repo: { id: 42, full_name: 'foo/foo' } }
      }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/issues/44',
      body: {
        number: 50, title: 'some title 50', state: 'closed',
        closed_at: Time.parse('2025-09-30 18:00:00 UTC'),
        closed_by: { login: 'user2', id: 422 }
      }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/44/reviews?per_page=100',
      body: [
        {
          id: 123, user: { id: 421, login: 'user', type: 'User' },
          submitted_at: Time.parse('2025-09-30 16:00:00 UTC')
        },
        { id: 124, user: { id: 999, login: 'robot', type: 'Bot' }, submitted_at: Time.parse('2025-09-30 17:00:00 UTC') }
      ]
    )
    stub_github('https://api.github.com/repos/foo/foo/pulls/44/reviews/123/comments?per_page=100', body: [])
    stub_github('https://api.github.com/repos/foo/foo/pulls/44/reviews/124/comments?per_page=100', body: [])
    stub_github('https://api.github.com/repos/foo/foo/pulls/44/comments?per_page=100', body: [])
    stub_github(
      'https://api.github.com/repos/foo/foo/issues/44/comments?per_page=100',
      body: [{ id: 100, user: nil }]
    )
    stub_github('https://api.github.com/repos/foo/foo/issues/comments/100/reactions', body: [])
    stub_github(
      'https://api.github.com/repos/foo/foo/commits/aa123/check-runs?per_page=100', body: { check_runs: [] }
    )
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-opened', repository: 42, issue: 44, where: 'github')
    Fbe.stub(:github_graph, Fbe::Graph::Fake.new) do
      load_it('pull-was-merged', fb)
      refute_includes(
        fb.query(
          "(and (eq what 'pull-was-closed') (eq repository 42) (eq where 'github') (eq issue 44))"
        ).each.first.all_properties,
        'review',
        'a review by the author, and a review by a bot, cannot mark the pull reviewed'
      )
    end
  end
end
