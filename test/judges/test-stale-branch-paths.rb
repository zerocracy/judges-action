# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../fake_github'
require_relative '../test__helper'

class TestStaleBranchPaths < Jp::Test
  using SmartFactbase

  PULL = {
    number: 44, pull_request: { url: 'https://api.github.com/repos/foo/foo/pulls/44' },
    user: { id: 4242 }, created_at: '2025-05-05T00:00:00Z'
  }.freeze

  ROUTES = {
    'GET /rate_limit' => { resources: { search: { remaining: 30, limit: 30 } }, rate: { remaining: 1000 } },
    'GET /repos/foo/foo' => { id: 42, full_name: 'foo/foo' },
    'GET /repositories/42' => { id: 42, full_name: 'foo/foo' },
    'GET /repos/foo/foo/pulls/44' => { number: 44, state: 'closed', head: { sha: 'abc123' } },
    'GET /user/4242' => { id: 4242, login: 'user' }
  }.freeze

  {
    'find-all-issues' => [
      [{ what: 'pull-was-opened', issue: 40 }],
      {
        'GET /repos/foo/foo/issues/40' => { number: 40, created_at: '2025-05-04T00:00:00Z' },
        'GET /search/issues?order=asc&per_page=100&q=repo%3Afoo%2Ffoo+type%3Apull+created%3A%3E%3D2025-05-04' \
        '&sort=created' => { total_count: 1, incomplete_results: false, items: [PULL] }
      }
    ],
    'find-earliest-issue' => [
      [],
      { 'GET /repos/foo/foo/issues?direction=asc&page=1&per_page=1&sort=created&state=all' => [PULL] }
    ],
    'find-latest-issue' => [
      [],
      { 'GET /repos/foo/foo/issues?direction=desc&page=1&per_page=1&sort=created&state=all' => [PULL] }
    ],
    'find-missing-issues' => [
      [{ what: 'issue-was-opened', issue: 43 }, { what: 'issue-was-opened', issue: 45 }],
      { 'GET /repos/foo/foo/issues/44' => PULL }
    ],
    'fix-missing-branch' => [[{ what: 'pull-was-opened', issue: 44 }], {}]
  }.each do |judge, (facts, routes)|
    define_method("test_#{judge.tr('-', '_')}_marks_pull_without_head_ref_stale") do
      fb = Factbase.new
      facts.each_with_index { |f, i| fb.with(_id: i + 1, repository: 42, where: 'github', **f) }
      Jp::FakeGithub.new(ROUTES.merge(routes)).run do
        load_it(judge, fb)
      end
      assert_equal(
        ['branch'], fb.pick(what: 'pull-was-opened', issue: 44)['stale'],
        "#{judge} must mark the pull as stale when GitHub returns it without a head ref"
      )
    end
  end
end
