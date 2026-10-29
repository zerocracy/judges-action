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

  def test_goes_on_after_connection_failure_on_pull_request_lookup
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-merged', repository: 42, issue: 44, where: 'github')
    fb.with(_id: 2, what: 'pull-was-merged', repository: 42, issue: 45, where: 'github')
    Jp::FakeGithub.new(
      'GET /rate_limit' => { resources: { search: { remaining: 30, limit: 30 } }, rate: { remaining: 1000 } },
      'GET /repos/foo/foo' => { id: 42, full_name: 'foo/foo' },
      'GET /repositories/42' => { id: 42, full_name: 'foo/foo' },
      'GET /repos/foo/foo/pulls/45' => { number: 45, additions: 3, deletions: 4 }
    ).run do
      stub_request(:get, %r{/repos/foo/foo/pulls/44\z}).to_raise(Faraday::ConnectionFailed.new('reset by peer'))
      load_it('fix-missing-hoc', fb)
    end
    assert_nil(fb.pick(issue: 44)['hoc'], 'hoc is saved for the pull that was never read')
    assert_equal(7, fb.pick(issue: 45).hoc, 'the next pull was not visited after a dropped connection')
  end

  def test_goes_on_after_timeout_on_pull_request_lookup
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-closed', repository: 42, issue: 44, where: 'github')
    fb.with(_id: 2, what: 'pull-was-closed', repository: 42, issue: 45, where: 'github')
    Jp::FakeGithub.new(
      'GET /rate_limit' => { resources: { search: { remaining: 30, limit: 30 } }, rate: { remaining: 1000 } },
      'GET /repos/foo/foo' => { id: 42, full_name: 'foo/foo' },
      'GET /repositories/42' => { id: 42, full_name: 'foo/foo' },
      'GET /repos/foo/foo/pulls/45' => { number: 45, additions: 10, deletions: 0 }
    ).run do
      stub_request(:get, %r{/repos/foo/foo/pulls/44\z}).to_raise(Faraday::TimeoutError.new('read timeout'))
      load_it('fix-missing-hoc', fb)
    end
    assert_nil(fb.pick(issue: 44)['hoc'], 'hoc is saved for the pull whose lookup timed out')
    assert_equal(10, fb.pick(issue: 45).hoc, 'the next pull was not visited after a timeout')
  end
end
