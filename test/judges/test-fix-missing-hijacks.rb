# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'fbe/github_graph'
require_relative '../test__helper'

class TestFixMissingHijacks < Jp::Test
  using SmartFactbase

  def test_counts_hijacks_of_old_merged_pull
    WebMock.disable_net_connect!
    rate_limit_up
    stub_merged_pull(44)
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-merged', repository: 42, issue: 44, where: 'github')
    Fbe.stub(:github_graph, stub_closing_issues({ 40 => [7_001] })) do
      load_it('fix-missing-hijacks', fb)
      assert(
        fb.one?(issue: 44, what: 'pull-was-merged', assignee: 7_001, hijacks: 1),
        'an old merged pull that hijacked an issue stays unjudged'
      )
    end
  end

  def test_counts_no_hijacks_of_clean_old_merged_pull
    WebMock.disable_net_connect!
    rate_limit_up
    stub_merged_pull(44)
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-merged', repository: 42, issue: 44, where: 'github')
    Fbe.stub(:github_graph, stub_closing_issues({ 40 => [421] })) do
      load_it('fix-missing-hijacks', fb)
      assert(
        fb.one?(issue: 44, what: 'pull-was-merged', hijacks: 0),
        'an old merged pull that closed its own author issue is left without a hijack count'
      )
    end
  end

  def test_leaves_alone_pull_that_was_already_judged
    WebMock.disable_net_connect!
    rate_limit_up
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-merged', repository: 42, issue: 44, where: 'github', hijacks: 3)
    Fbe.stub(:github_graph, stub_closing_issues({ 40 => [7_001] })) do
      load_it('fix-missing-hijacks', fb)
      assert(
        fb.one?(issue: 44, what: 'pull-was-merged', hijacks: 3),
        'a pull that already knows its hijacks is judged again'
      )
    end
  end

  def test_leaves_alone_pull_that_was_closed_without_merging
    WebMock.disable_net_connect!
    rate_limit_up
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-closed', repository: 42, issue: 44, where: 'github')
    Fbe.stub(:github_graph, stub_closing_issues({ 40 => [7_001] })) do
      load_it('fix-missing-hijacks', fb)
      refute_includes(
        fb.pick(issue: 44, what: 'pull-was-closed').all_properties,
        'hijacks',
        'a pull that was closed without merging is judged for hijacking'
      )
    end
  end

  def test_retries_later_when_closing_issues_cannot_be_read
    WebMock.disable_net_connect!
    rate_limit_up
    stub_merged_pull(44)
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-merged', repository: 42, issue: 44, where: 'github')
    graph =
      Class.new(Fbe::Graph::Fake) do
        define_method(:query) do |_qry|
          raise(Octokit::Forbidden.new(method: :get, url: 'https://api.github.com', status: 403, body: 'Forbidden'))
        end
      end.new
    Fbe.stub(:github_graph, graph) do
      load_it('fix-missing-hijacks', fb)
      refute_includes(
        fb.pick(issue: 44, what: 'pull-was-merged').all_properties,
        'hijacks',
        'a pull with unreadable closing issues is judged as clean'
      )
    end
  end

  def test_retries_later_when_pull_is_forbidden
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/44',
      status: 403, body: { message: 'Resource not accessible by integration' }
    )
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-merged', repository: 42, issue: 44, where: 'github')
    Fbe.stub(:github_graph, stub_closing_issues({ 40 => [7_001] })) do
      load_it('fix-missing-hijacks', fb)
      refute_includes(
        fb.pick(issue: 44, what: 'pull-was-merged').all_properties,
        'stale',
        'a forbidden pull is marked stale instead of being retried next cycle'
      )
    end
  end

  def test_stales_pull_that_does_not_exist_anymore
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, full_name: 'foo/foo' })
    stub_github('https://api.github.com/repos/foo/foo/pulls/44', status: 404, body: { message: 'Not Found' })
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-merged', repository: 42, issue: 44, where: 'github')
    Fbe.stub(:github_graph, stub_closing_issues({ 40 => [7_001] })) do
      load_it('fix-missing-hijacks', fb)
      assert(
        fb.one?(what: 'pull-was-merged', repository: 42, issue: 44, where: 'github', stale: 'issue'),
        'a pull that vanished from GitHub is not marked as stale'
      )
    end
  end

  private

  def stub_closing_issues(issues)
    Class.new(Fbe::Graph::Fake) do
      define_method(:query) do |qry|
        next {} unless qry.include?('closingIssuesReferences')
        {
          'repository' => {
            'pullRequest' => {
              'closingIssuesReferences' => {
                'pageInfo' => { 'hasNextPage' => false, 'endCursor' => nil },
                'nodes' => issues.map do |number, ids|
                  { 'number' => number, 'assignees' => { 'nodes' => ids.map { |id| { 'databaseId' => id } } } }
                end
              }
            }
          }
        }
      end
    end.new
  end

  def stub_merged_pull(issue)
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, full_name: 'foo/foo' })
    stub_github(
      "https://api.github.com/repos/foo/foo/pulls/#{issue}",
      body: {
        id: 50, number: issue, user: { id: 421, login: 'user' }, state: 'closed',
        merged_at: Time.parse('2025-09-30 18:00:00 UTC'),
        closed_at: Time.parse('2025-09-30 18:00:00 UTC'),
        head: { ref: '40', sha: 'aa123' },
        base: { repo: { id: 42, full_name: 'foo/foo' } }
      }
    )
  end
end
