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

  def test_sums_additions_and_deletions
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-merged', repository: 42, issue: 44, where: 'github')
    Jp::FakeGithub.new(
      'GET /rate_limit' => { resources: { search: { remaining: 30, limit: 30 } }, rate: { remaining: 1000 } },
      'GET /repositories/42' => { id: 42, full_name: 'foo/foo' },
      'GET /repos/foo/foo/pulls/44' => { id: 50, number: 44, state: 'closed', additions: 5, deletions: 3 }
    ).run do
      load_it('fix-missing-hoc', fb)
    end
    assert_equal(
      8, fb.pick(issue: 44).hoc,
      'the hoc must be the sum of additions and deletions, or the pull is rewarded for a different amount of work'
    )
  end

  def test_uses_additions_when_deletions_are_absent
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-merged', repository: 42, issue: 44, where: 'github')
    Jp::FakeGithub.new(
      'GET /rate_limit' => { resources: { search: { remaining: 30, limit: 30 } }, rate: { remaining: 1000 } },
      'GET /repositories/42' => { id: 42, full_name: 'foo/foo' },
      'GET /repos/foo/foo/pulls/44' => { id: 50, number: 44, state: 'closed', additions: 5 }
    ).run do
      load_it('fix-missing-hoc', fb)
    end
    assert_equal(
      5, fb.pick(issue: 44).hoc,
      'the hoc must be the additions the API reported, even when it did not report deletions'
    )
    assert_nil(
      fb.pick(issue: 44)['stale'],
      'a pull request reporting only one of the two numbers must not be marked stale, or its hoc is lost for good'
    )
  end

  def test_handles_selection_rules_and_single_diff_metric
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-merged', repository: 42, issue: 44, where: 'github', hoc: 10)
    fb.with(_id: 2, what: 'pull-was-closed', repository: 42, issue: 45, where: 'github')
    fb.with(_id: 3, what: 'pull-was-merged', repository: 42, issue: 46, where: 'github', done: 1)
    fb.with(_id: 4, what: 'pull-was-merged', repository: 42, issue: 47, where: 'github', tombstone: 'yes')
    fb.with(_id: 5, what: 'pull-was-merged', repository: 42, issue: 48, where: 'github')
    fb.with(_id: 6, what: 'pull-was-merged', repository: 42, issue: 49, where: 'github')
    Jp::FakeGithub.new(
      'GET /rate_limit' => { resources: { search: { remaining: 30, limit: 30 } }, rate: { remaining: 1000 } },
      'GET /repos/foo/foo' => { id: 42, full_name: 'foo/foo' },
      'GET /repositories/42' => { id: 42, full_name: 'foo/foo' },
      'GET /repos/foo/foo/pulls/44' => { id: 50, number: 44, additions: 4, deletions: 3 },
      'GET /repos/foo/foo/pulls/45' => { id: 51, number: 45, additions: 6, deletions: 5 },
      'GET /repos/foo/foo/pulls/46' => { id: 52, number: 46, additions: 8, deletions: 7 },
      'GET /repos/foo/foo/pulls/47' => { id: 53, number: 47, additions: 2, deletions: 1 },
      'GET /repos/foo/foo/pulls/48' => { id: 54, number: 48, deletions: 9 },
      'GET /repos/foo/foo/pulls/49' => { id: 55, number: 49, additions: 8 }
    ).run do
      load_it('fix-missing-hoc', fb)
    end
    assert_equal([10], fb.pick(issue: 44)['hoc'], 'the fact already having hoc changed')
    assert_equal([11], fb.pick(issue: 45)['hoc'], 'the closed pull request got no hoc')
    assert_nil(fb.pick(issue: 46)['hoc'], 'a done fact got a hoc')
    assert_nil(fb.pick(issue: 47)['hoc'], 'a tombstoned fact got a hoc')
    assert_equal([9], fb.pick(issue: 48)['hoc'], 'a pull with only deletions got no hoc')
    assert_nil(fb.pick(issue: 48)['stale'], 'a pull with deletions was marked stale')
    assert_equal([8], fb.pick(issue: 49)['hoc'], 'a pull with only additions got no hoc')
    assert_nil(fb.pick(issue: 49)['stale'], 'a pull with additions was marked stale')
  end
end
