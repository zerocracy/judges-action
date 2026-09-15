# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'fbe/github_graph'
require_relative '../test__helper'

class TestPullWasMergedHead < Jp::Test
  using SmartFactbase

  def test_marks_a_pull_without_a_head_as_stale
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
    stub_github('https://api.github.com/repos/foo/foo/pulls/44/reviews?per_page=100', body: [])
    stub_github('https://api.github.com/repos/foo/foo/pulls/44/comments?per_page=100', body: [])
    stub_github('https://api.github.com/repos/foo/foo/commits//check-runs?per_page=100', body: { check_runs: [] })
    stub_github(
      'https://api.github.com/repos/foo/foo/issues/44/comments?per_page=100',
      body: [{ id: 100, user: nil }]
    )
    stub_github('https://api.github.com/repos/foo/foo/issues/comments/100/reactions', body: [])
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-opened', repository: 42, issue: 44, where: 'github')
    Fbe.stub(:github_graph, Fbe::Graph::Fake.new) do
      load_it('pull-was-merged', fb)
      f = fb.query("(and (eq what 'pull-was-closed') (eq repository 42) (eq issue 44))").each.first
      refute_nil(f, 'a pull with no head must still become a fact')
      assert_equal(['branch'], f['stale'], 'a pull with no head must be marked stale')
    end
  end
end
