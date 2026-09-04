# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../fake_github'
require_relative '../test__helper'

class TestFixMissingBranch < Jp::Test
  using SmartFactbase

  def test_finds_branch_via_pull_request
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-opened', repository: 42, issue: 44, where: 'github')
    Jp::FakeGithub.new(
      'GET /rate_limit' => { resources: { search: { remaining: 30, limit: 30 } }, rate: { remaining: 1000 } },
      'GET /repos/foo/foo' => { id: 42, full_name: 'foo/foo' },
      'GET /repositories/42' => { id: 42, full_name: 'foo/foo' },
      'GET /repos/foo/foo/pulls/44' => {
        number: 44, state: 'open', head: { ref: 'feature-branch', sha: 'abc123' }
      }
    ).run do
      load_it('fix-missing-branch', fb)
    end
    assert_equal(
      'feature-branch', fb.pick(issue: 44).branch,
      'the branch is not the head ref of the pull request, while the judge must copy it from there'
    )
  end

  def test_rescues_forbidden_on_pull_request_lookup
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-opened', repository: 42, issue: 44, where: 'github')
    Jp::FakeGithub.new(
      'GET /rate_limit' => { resources: { search: { remaining: 30, limit: 30 } }, rate: { remaining: 1000 } },
      'GET /repos/foo/foo' => { id: 42, full_name: 'foo/foo' },
      'GET /repositories/42' => { id: 42, full_name: 'foo/foo' },
      'GET /repos/foo/foo/pulls/44' => [403, { message: 'Resource not accessible by integration' }]
    ).run do
      load_it('fix-missing-branch', fb)
    end
    assert_nil(
      fb.pick(issue: 44)['stale'],
      'the fact is stale after a transient 403, while the next cycle must retry the pull request lookup'
    )
  end

  def test_rescues_not_found_on_repo_name_lookup
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-opened', repository: 42, issue: 44, where: 'github')
    Jp::FakeGithub.new(
      'GET /rate_limit' => { resources: { search: { remaining: 30, limit: 30 } }, rate: { remaining: 1000 } },
      'GET /repositories/42' => [404, { message: 'Not Found' }]
    ).run do
      load_it('fix-missing-branch', fb)
    end
    assert(
      fb.one?(what: 'pull-was-opened', repository: 42, stale: 'repository'),
      'the fact of a vanished repository is not stale, while the judge must mark it instead of aborting'
    )
  end
end
