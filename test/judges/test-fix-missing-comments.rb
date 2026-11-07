# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'fbe/github_graph'
require_relative '../fake_github'
require_relative '../test__helper'

class TestFixMissingComments < Jp::Test
  using SmartFactbase

  def test_rescues_forbidden_on_pull_lookup
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-merged', repository: 42, issue: 44, where: 'github')
    Jp::FakeGithub.new(
      'GET /rate_limit' => { resources: { search: { remaining: 30, limit: 30 } }, rate: { remaining: 1000 } },
      'GET /repos/foo/foo' => { id: 42, full_name: 'foo/foo' },
      'GET /repositories/42' => { id: 42, full_name: 'foo/foo' },
      'GET /repos/foo/foo/pulls/44' => [403, { message: 'Resource not accessible by integration' }]
    ).run do
      load_it('fix-missing-comments', fb)
    end
    assert_equal(
      %w[_id issue repository what where], fb.pick(issue: 44).all_properties.sort,
      'the fact changed after 403, while the pull request was never read and the next cycle must retry'
    )
  end

  def test_leaves_comments_absent_when_they_are_forbidden
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-merged', repository: 42, issue: 44, where: 'github')
    Jp::FakeGithub.new(
      'GET /rate_limit' => { resources: { search: { remaining: 30, limit: 30 } }, rate: { remaining: 1000 } },
      'GET /repos/foo/foo' => { id: 42, full_name: 'foo/foo' },
      'GET /repositories/42' => { id: 42, full_name: 'foo/foo' },
      'GET /repos/foo/foo/pulls/44' => { number: 44, user: { id: 7 }, base: { repo: { full_name: 'foo/foo' } } },
      'GET /repos/foo/foo/pulls/44/comments?per_page=100' => [403, { message: 'Ограничение скорости' }]
    ).run do
      Fbe.stub(:github_graph, Fbe::Graph::Fake.new) { load_it('fix-missing-comments', fb) }
    end
    assert_nil(fb.pick(issue: 44)['comments'], 'comments are saved although the api refused them')
  end

  def test_rescues_not_found_on_repo_name_lookup
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-merged', repository: 42, issue: 44, where: 'github')
    Jp::FakeGithub.new(
      'GET /rate_limit' => { resources: { search: { remaining: 30, limit: 30 } }, rate: { remaining: 1000 } },
      'GET /repositories/42' => [404, { message: 'Not Found' }]
    ).run do
      load_it('fix-missing-comments', fb)
    end
    assert(
      fb.one?(what: 'pull-was-merged', repository: 42, stale: 'repository'),
      'the fact of a vanished repository is not stale, while the judge must mark it instead of aborting'
    )
  end

  def test_handles_selection_rules
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-merged', repository: 42, issue: 44, where: 'github', comments: 1)
    fb.with(_id: 2, what: 'pull-was-closed', repository: 42, issue: 45, where: 'github')
    fb.with(_id: 3, what: 'pull-was-merged', repository: 42, issue: 46, where: 'github', done: 1)
    fb.with(_id: 4, what: 'pull-was-merged', repository: 42, issue: 47, where: 'github', tombstone: 'yes')
    Jp::FakeGithub.new(
      'GET /rate_limit' => { resources: { search: { remaining: 30, limit: 30 } }, rate: { remaining: 1000 } },
      'GET /repos/foo/foo' => { id: 42, full_name: 'foo/foo' },
      'GET /repositories/42' => { id: 42, full_name: 'foo/foo' },
      'GET /repos/foo/foo/pulls/44' => { number: 44, user: { id: 7 }, base: { repo: { full_name: 'foo/foo' } } },
      'GET /repos/foo/foo/pulls/44/comments?per_page=100' => [{ id: 1, user: { id: 8, login: 'b', type: 'User' } }],
      'GET /repos/foo/foo/issues/44/comments?per_page=100' => [{ id: 2, user: { id: 9, login: 'a', type: 'User' } }],
      'GET /repos/foo/foo/pulls/comments/1/reactions' => [],
      'GET /repos/foo/foo/issues/comments/2/reactions' => [],
      'GET /repos/foo/foo/pulls/45' => { number: 45, user: { id: 7 }, base: { repo: { full_name: 'foo/foo' } } },
      'GET /repos/foo/foo/pulls/45/comments?per_page=100' => [{ id: 3, user: { id: 8, login: 'b', type: 'User' } }],
      'GET /repos/foo/foo/issues/45/comments?per_page=100' => [{ id: 4, user: { id: 9, login: 'a', type: 'User' } }],
      'GET /repos/foo/foo/pulls/comments/3/reactions' => [],
      'GET /repos/foo/foo/issues/comments/4/reactions' => [],
      'GET /repos/foo/foo/pulls/46' => { number: 46, user: { id: 7 }, base: { repo: { full_name: 'foo/foo' } } },
      'GET /repos/foo/foo/pulls/46/comments?per_page=100' => [{ id: 5, user: { id: 8, login: 'b', type: 'User' } }],
      'GET /repos/foo/foo/issues/46/comments?per_page=100' => [{ id: 6, user: { id: 9, login: 'a', type: 'User' } }],
      'GET /repos/foo/foo/pulls/comments/5/reactions' => [],
      'GET /repos/foo/foo/issues/comments/6/reactions' => [],
      'GET /repos/foo/foo/pulls/47' => { number: 47, user: { id: 7 }, base: { repo: { full_name: 'foo/foo' } } },
      'GET /repos/foo/foo/pulls/47/comments?per_page=100' => [{ id: 7, user: { id: 8, login: 'b', type: 'User' } }],
      'GET /repos/foo/foo/issues/47/comments?per_page=100' => [{ id: 8, user: { id: 9, login: 'a', type: 'User' } }],
      'GET /repos/foo/foo/pulls/comments/7/reactions' => [],
      'GET /repos/foo/foo/issues/comments/8/reactions' => []
    ).run do
      Fbe.stub(:github_graph, Fbe::Graph::Fake.new) { load_it('fix-missing-comments', fb) }
    end
    assert_equal([1], fb.pick(issue: 44)['comments'], 'the fact already having comments changed')
    assert_equal([2], fb.pick(issue: 45)['comments'], 'the closed pull request got no comments')
    assert_nil(fb.pick(issue: 46)['comments'], 'a done fact got comments')
    assert_nil(fb.pick(issue: 47)['comments'], 'a tombstoned fact got comments')
  end

  def test_goes_on_after_server_error_on_pull_comments
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-merged', repository: 42, issue: 44, where: 'github')
    fb.with(_id: 2, what: 'pull-was-merged', repository: 42, issue: 45, where: 'github')
    Jp::FakeGithub.new(
      'GET /rate_limit' => { resources: { search: { remaining: 30, limit: 30 } }, rate: { remaining: 1000 } },
      'GET /repos/foo/foo' => { id: 42, full_name: 'foo/foo' },
      'GET /repositories/42' => { id: 42, full_name: 'foo/foo' },
      'GET /repos/foo/foo/pulls/44' => { number: 44, user: { id: 7 }, base: { repo: { full_name: 'foo/foo' } } },
      'GET /repos/foo/foo/pulls/45' => { number: 45, user: { id: 7 }, base: { repo: { full_name: 'foo/foo' } } },
      'GET /repos/foo/foo/pulls/44/comments?per_page=100' => [500, { message: 'boom' }],
      'GET /repos/foo/foo/pulls/45/comments?per_page=100' => [],
      'GET /repos/foo/foo/issues/45/comments?per_page=100' => []
    ).run do
      Fbe.stub(:github_graph, Fbe::Graph::Fake.new) { load_it('fix-missing-comments', fb) }
    end
    assert_nil(fb.pick(issue: 44)['comments'], 'comments are saved for the pull whose comments failed with 500')
    refute_nil(fb.pick(issue: 45)['comments'], 'the next pull was not visited after a 500 on the previous one')
  end

  def test_goes_on_after_server_error_on_issue_comments
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-merged', repository: 42, issue: 44, where: 'github')
    fb.with(_id: 2, what: 'pull-was-merged', repository: 42, issue: 45, where: 'github')
    Jp::FakeGithub.new(
      'GET /rate_limit' => { resources: { search: { remaining: 30, limit: 30 } }, rate: { remaining: 1000 } },
      'GET /repos/foo/foo' => { id: 42, full_name: 'foo/foo' },
      'GET /repositories/42' => { id: 42, full_name: 'foo/foo' },
      'GET /repos/foo/foo/pulls/44' => { number: 44, user: { id: 7 }, base: { repo: { full_name: 'foo/foo' } } },
      'GET /repos/foo/foo/pulls/45' => { number: 45, user: { id: 7 }, base: { repo: { full_name: 'foo/foo' } } },
      'GET /repos/foo/foo/pulls/44/comments?per_page=100' => [],
      'GET /repos/foo/foo/issues/44/comments?per_page=100' => [500, { message: 'unavailable' }],
      'GET /repos/foo/foo/pulls/45/comments?per_page=100' => [],
      'GET /repos/foo/foo/issues/45/comments?per_page=100' => []
    ).run do
      Fbe.stub(:github_graph, Fbe::Graph::Fake.new) { load_it('fix-missing-comments', fb) }
    end
    assert_nil(fb.pick(issue: 44)['comments'], 'comments are saved for the pull whose issue comments failed with 500')
    refute_nil(fb.pick(issue: 45)['comments'], 'the next pull was not visited after a 500 on the previous one')
  end
end
