# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../fake_github'
require_relative '../test__helper'

class TestFixMissingHoc < Jp::Test
  using SmartFactbase

  def test_rescues_forbidden_on_pull_request_lookup
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-merged', repository: 42, issue: 44, where: 'github')
    Jp::FakeGithub.new(
      'GET /rate_limit' => { resources: { search: { remaining: 30, limit: 30 } }, rate: { remaining: 1000 } },
      'GET /repos/foo/foo' => { id: 42, full_name: 'foo/foo' },
      'GET /repositories/42' => { id: 42, full_name: 'foo/foo' },
      'GET /repos/foo/foo/pulls/44' => [403, { message: 'Resource not accessible by integration' }]
    ).run do
      load_it('fix-missing-hoc', fb)
    end
    assert_equal(
      %w[_id issue repository what where], fb.pick(issue: 44).all_properties.sort,
      'the fact changed after a 403, while the pull request was never read and the next cycle must retry'
    )
  end

  def test_rescues_not_found_on_repo_name_lookup
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-merged', repository: 42, issue: 44, where: 'github')
    Jp::FakeGithub.new(
      'GET /rate_limit' => { resources: { search: { remaining: 30, limit: 30 } }, rate: { remaining: 1000 } },
      'GET /repositories/42' => [404, { message: 'Not Found' }]
    ).run do
      load_it('fix-missing-hoc', fb)
    end
    assert(
      fb.one?(what: 'pull-was-merged', repository: 42, stale: 'repository'),
      'the fact of a vanished repository is not stale, while the judge must mark it instead of aborting'
    )
  end

  def test_marks_stale_when_pull_reports_no_hoc
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-merged', repository: 42, issue: 44, where: 'github')
    Jp::FakeGithub.new(
      'GET /rate_limit' => { resources: { search: { remaining: 30, limit: 30 } }, rate: { remaining: 1000 } },
      'GET /repositories/42' => { id: 42, full_name: 'foo/foo' },
      'GET /repos/foo/foo/pulls/44' => { id: 50, number: 44, state: 'closed', changed_files: 1 }
    ).run do
      load_it('fix-missing-hoc', fb)
    end
    assert_nil(fb.pick(issue: 44)['hoc'], 'a number the API never gave must not be invented')
    assert_equal(
      'hoc', fb.pick(issue: 44).stale,
      'a pull request reporting no additions and no deletions must be marked stale, not scored as empty'
    )
  end

  def test_fills_hoc_of_pull_stale_only_by_who
    seed = Random.new_seed
    random = Random.new(seed)
    additions = random.rand(10_000)
    deletions = random.rand(10_000)
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-merged', repository: 42, issue: 44, where: 'github', stale: 'who')
    Jp::FakeGithub.new(
      'GET /rate_limit' => { resources: { search: { remaining: 30, limit: 30 } }, rate: { remaining: 1000 } },
      'GET /repositories/42' => { id: 42, full_name: 'foo/foo' },
      'GET /repos/foo/foo/pulls/44' => { id: 50, number: 44, state: 'closed', additions:, deletions: }
    ).run do
      load_it('fix-missing-hoc', fb)
    end
    assert_equal(
      [additions + deletions], fb.pick(issue: 44)['hoc'],
      "the hoc of a pull that lost only its author is not filled, seed #{seed}"
    )
  end

  def test_skips_pull_stale_by_who_and_by_repository
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-merged', repository: 42, issue: 44, where: 'github', stale: 'who')
    fb.pick(issue: 44).stale = 'repository'
    Jp::FakeGithub.new(
      'GET /rate_limit' => { resources: { search: { remaining: 30, limit: 30 } }, rate: { remaining: 1000 } },
      'GET /repositories/42' => { id: 42, full_name: 'foo/foo' },
      'GET /repos/foo/foo/pulls/44' => { id: 50, number: 44, state: 'closed', additions: 7, deletions: 3 }
    ).run do
      load_it('fix-missing-hoc', fb)
    end
    assert_nil(fb.pick(issue: 44)['hoc'], 'the hoc of a pull stale for more than its author is filled')
  end
end
