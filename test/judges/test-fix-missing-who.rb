# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../fake_github'
require_relative '../test__helper'

class TestFixMissingWho < Jp::Test
  using SmartFactbase

  def test_rescues_forbidden_on_issue_lookup
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-opened', repository: 42, issue: 44, where: 'github')
    Jp::FakeGithub.new(
      'GET /rate_limit' => { resources: { search: { remaining: 30, limit: 30 } }, rate: { remaining: 1000 } },
      'GET /repos/foo/foo' => { id: 42, full_name: 'foo/foo' },
      'GET /repositories/42' => { id: 42, full_name: 'foo/foo' },
      'GET /repos/foo/foo/issues/44' => [403, { message: 'Resource not accessible by integration' }]
    ).run do
      load_it('fix-missing-who', fb)
    end
    assert_nil(
      fb.pick(issue: 44)['stale'],
      'the fact is stale after a transient 403, while the next cycle must retry the issue lookup'
    )
  end

  def test_rescues_deprecated_on_issue_lookup
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, issue: 55, where: 'github')
    Jp::FakeGithub.new(
      'GET /rate_limit' => { resources: { search: { remaining: 30, limit: 30 } }, rate: { remaining: 1000 } },
      'GET /repos/foo/foo' => { id: 42, full_name: 'foo/foo' },
      'GET /repositories/42' => { id: 42, full_name: 'foo/foo' },
      'GET /repos/foo/foo/issues/55' => [410, { message: 'Issues are disabled for this repo' }]
    ).run do
      load_it('fix-missing-who', fb)
    end
    assert_equal(
      'issue', fb.pick(issue: 55)['stale'].first,
      'the issue is not stale after a permanent 410, while the judge must give up on it'
    )
  end

  def test_reads_merged_by_from_pull_endpoint
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-merged', repository: 42, issue: 66, where: 'github')
    Jp::FakeGithub.new(
      'GET /rate_limit' => { resources: { search: { remaining: 30, limit: 30 } }, rate: { remaining: 1000 } },
      'GET /repos/foo/foo' => { id: 42, full_name: 'foo/foo' },
      'GET /repositories/42' => { id: 42, full_name: 'foo/foo' },
      'GET /repos/foo/foo/pulls/66' => { number: 66, merged_by: { id: 7, login: 'merger' } }
    ).run do
      load_it('fix-missing-who', fb)
    end
    assert_equal(
      7, fb.pick(issue: 66).who,
      'the author is not the merged_by user of the pull request, while the judge must copy it from there'
    )
  end

  def test_rescues_not_found_on_repo_name_lookup
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-opened', repository: 42, issue: 44, where: 'github')
    Jp::FakeGithub.new(
      'GET /rate_limit' => { resources: { search: { remaining: 30, limit: 30 } }, rate: { remaining: 1000 } },
      'GET /repositories/42' => [404, { message: 'Not Found' }]
    ).run do
      load_it('fix-missing-who', fb)
    end
    assert(
      fb.one?(what: 'pull-was-opened', repository: 42, stale: 'repository'),
      'the fact of a vanished repository is not stale, while the judge must mark it instead of aborting'
    )
  end

  def test_reads_closed_by_for_closed_issue
    fb = whos_after(44 => { what: 'issue-was-closed' })
    assert_equal([9], fb.pick(issue: 44)['who'], 'the closer of the issue was not found')
  end

  def test_keeps_the_who_a_fact_already_has
    fb = whos_after(45 => { what: 'issue-was-opened', who: 5 })
    assert_equal([5], fb.pick(issue: 45)['who'], 'the who of the fact changed')
  end

  def test_skips_done_fact
    fb = whos_after(46 => { what: 'issue-was-opened', done: 1 })
    assert_nil(fb.pick(issue: 46)['who'], 'a done fact got a who')
  end

  def test_skips_buried_fact
    fb = whos_after(47 => { what: 'issue-was-closed', tombstone: 'yes' })
    assert_nil(fb.pick(issue: 47)['who'], 'a buried fact got a who')
  end

  private

  def whos_after(facts)
    fb = Factbase.new
    facts.each_with_index do |(n, extra), i|
      fb.with(_id: i + 1, repository: 42, issue: n, where: 'github', **extra)
    end
    Jp::FakeGithub.new(
      {
        'GET /rate_limit' => { resources: { search: { remaining: 30, limit: 30 } }, rate: { remaining: 1000 } },
        'GET /repos/foo/foo' => { id: 42, full_name: 'foo/foo' },
        'GET /repositories/42' => { id: 42, full_name: 'foo/foo' }
      }.merge(
        facts.keys.to_h do |n|
          ["GET /repos/foo/foo/issues/#{n}", { number: n, user: { id: n - 38 }, closed_by: { id: 9 } }]
        end
      )
    ).run do
      load_it('fix-missing-who', fb)
    end
    fb
  end
end
