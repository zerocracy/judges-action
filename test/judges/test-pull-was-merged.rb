# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'decoor'
require 'fbe/github_graph'
require 'factbase'
require 'judges/options'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024 Yegor Bugayenko
# License:: MIT
class TestPullWasMerged < Jp::Test
  def test_find_closed_and_merged_pull_requests
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_github('https://api.github.com/repos/foo/foo/pulls/47', body: { id: 50, number: 47, state: 'open' })
    stub_github('https://api.github.com/repos/foo/foo/pulls/50', body: { id: 55, number: 50, state: 'open' })
    stub_github('https://api.github.com/repos/foo/foo/pulls/51',
                body: {
                  id: 60, number: 51, state: 'closed',
                  closed_at: Time.parse('2025-05-27T19:20:00Z'),
                  merged_at: Time.parse('2025-05-27T19:20:00Z'),
                  user: { id: 411, login: 'user' },
                  head: {
                    label: 'bar:master', ref: 'master', sha: '42b24481',
                    user: { id: 411, login: 'user' }, repo: { id: 43, name: 'bar', full_name: 'bar/bar' }
                  },
                  base: {
                    label: 'foo:master', ref: 'master', sha: '9f4767929',
                    user: { id: 422, login: 'user2' }, repo: { id: 42, name: 'foo', full_name: 'foo/foo' }
                  },
                  additions: 10, deletions: 5, changed_files: 1, comments: 1, review_comments: 2
                })
    stub_github('https://api.github.com/repos/foo/foo/issues/51', body: { closed_by: { id: 422, login: 'user2' } })
    stub_github('https://api.github.com/repos/foo/foo/pulls/51/comments?per_page=100',
                body: [
                  { id: 25, user: { id: 411, login: 'user' }, body: 'test comment' },
                  { id: 26, user: { id: 411, login: 'user' }, body: 'test comment 2' }
                ])
    stub_github('https://api.github.com/repos/foo/foo/issues/51/comments?per_page=100',
                body: [{ id: 27, user: { id: 411, login: 'user' }, body: 'test comment 3' }])
    stub_github('https://api.github.com/repos/foo/foo/issues/comments/27/reactions',
                body: [{ id: 127, user: { id: 411, login: 'user' }, content: '+1' }])
    stub_github('https://api.github.com/repos/foo/foo/pulls/comments/25/reactions',
                body: [{ id: 125, user: { id: 411, login: 'user' }, content: '+1' }])
    stub_github('https://api.github.com/repos/foo/foo/pulls/comments/26/reactions', body: [])
    stub_github('https://api.github.com/repos/foo/foo/commits/42b24481/check-runs?per_page=100',
                body: {
                  total_count: 2,
                  check_runs: [
                    { id: 111, name: 'reuse', app: { slug: 'github-actions' } },
                    { id: 112, name: 'typos', app: { slug: 'github-actions' } }
                  ]
                })
    stub_github('https://api.github.com/repos/foo/foo/actions/jobs/111', body: { run_id: 222 })
    stub_github('https://api.github.com/repos/foo/foo/actions/jobs/112', body: { run_id: 223 })
    stub_github('https://api.github.com/repos/foo/foo/actions/runs/222',
                body: { event: 'pull_request', conclusion: 'success' })
    stub_github('https://api.github.com/repos/foo/foo/actions/runs/223',
                body: { event: 'pull_request', conclusion: 'failure' })
    stub_github('https://api.github.com/user/422', body: { id: 422, login: 'user2' })
    fb = factbase
    fb.create(_id: 1, what: 'pull-was-opened', repository: 42, issue: 44, where: 'github')
    fb.create(_id: 2, what: 'pull-was-closed', repository: 42, issue: 44, where: 'github')
    fb.create(_id: 3, what: 'pull-was-opened', repository: 42, issue: 45, where: 'github')
    fb.create(_id: 4, what: 'pull-was-merged', repository: 42, issue: 45, where: 'github')
    fb.create(_id: 5, what: 'pull-was-opened', repository: 42, issue: 47, where: 'github')
    fb.create(_id: 6, what: 'pull-was-opened', repository: 42, issue: 49, where: 'github',
              watched: Time.parse('2025-05-27T10:20:00Z'))
    fb.create(_id: 7, what: 'pull-was-opened', repository: 42, issue: 50, where: 'github',
              watched: Time.parse('2025-05-26T19:20:00Z'))
    fb.create(_id: 8, what: 'pull-was-opened', repository: 42, issue: 51, where: 'github')
    fb.create(_id: 9, what: 'pull-was-opened', repository: 42, issue: 40, where: 'gitlab')
    Fbe.stub(:github_graph, Fbe::Graph::Fake.new) do
      now = Time.parse('2025-05-27 20:00:00 UTC')
      Time.stub(:now, now) do
        load_it('pull-was-merged', fb)
        assert_equal(7, fb.query('(eq what "pull-was-opened")').each.to_a.size)
        assert_equal(1, fb.query('(eq what "pull-was-closed")').each.to_a.size)
        assert_equal(2, fb.query('(eq what "pull-was-merged")').each.to_a.size)
        assert_nil(fb.find(what: 'pull-was-opened', repository: 42,
                           issue: 44, where: 'github').first['watched'])
        assert_nil(fb.find(what: 'pull-was-closed', repository: 42,
                           issue: 44, where: 'github').first['watched'])
        assert_nil(fb.find(what: 'pull-was-opened', repository: 42,
                           issue: 45, where: 'github').first['watched'])
        assert_nil(fb.find(what: 'pull-was-merged', repository: 42,
                           issue: 45, where: 'github').first['watched'])
        assert_equal(now,
                     fb.find(what: 'pull-was-opened', repository: 42,
                             issue: 47, where: 'github').first['watched'].last)
        assert_equal(Time.parse('2025-05-27T10:20:00Z'),
                     fb.find(what: 'pull-was-opened', repository: 42,
                             issue: 49, where: 'github').first['watched'].last)
        assert_equal(now,
                     fb.find(what: 'pull-was-opened', repository: 42,
                             issue: 50, where: 'github').first['watched'].last)
        assert_nil(fb.find(what: 'pull-was-opened', repository: 42,
                           issue: 51, where: 'github').first['watched'])
        assert_nil(fb.find(what: 'pull-was-opened', repository: 42,
                           issue: 40, where: 'gitlab').first['watched'])
        f = fb.find(what: 'pull-was-merged', repository: 42, issue: 51, where: 'github').first
        refute_nil(f)
        assert_equal(Time.parse('2025-05-27T19:20:00Z'), f.when)
        assert_equal(422, f.who)
        assert_equal(15, f.hoc)
        assert_equal(3, f.comments)
        assert_equal(2, f.comments_to_code)
        assert_equal(3, f.comments_by_author)
        assert_equal(0, f.comments_by_reviewers)
        assert_equal(0, f.comments_appreciated)
        assert_equal(0, f.comments_resolved)
        assert_equal(1, f.succeeded_builds)
        assert_equal(1, f.failed_builds)
        assert_equal('master', f.branch)
        assert_equal(
          'The pull request foo/foo#51 has been merged by @user2, with 15 HoC and 3 comments.',
          f.details
        )
      end
    end
  end

  private

  def factbase(fb = Factbase.new)
    decoor(fb) do
      def find(**props)
        eqs =
          props.map do |prop, value|
            val =
              case value
              when String then "'#{value}'"
              else value
              end
            "(eq #{prop} #{val})"
          end
        @origin.query("(and #{eqs.join(' ')})").each.to_a
      end

      def create(**props)
        @origin.insert.then do |f|
          props.each do |prop, value|
            f.send(:"#{prop}=", value)
          end
        end
      end
    end
  end
end
