# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'fbe/github_graph'
require 'judges/options'
require 'loog'
require_relative '../test__helper'

class TestTotalMetricsRescues < Jp::Test
  def test_total_stars_skips_missing_and_forbidden_repositories
    octo = Object.new
    octo.define_singleton_method(:repository) do |repo|
      raise(Octokit::NotFound) if repo == 'foo/missing'
      raise(Octokit::Forbidden) if repo == 'foo/blocked'
      { stargazers_count: 5, forks: 2 }
    end
    result =
      measure(
        'dimensions-of-terrain', 'total_stars', %w[foo/missing foo/blocked foo/good], octo,
        proc do
          total_stars(nil)
        end
      )
    assert_equal({ total_stars: 5, total_forks: 2 }, result)
  end

  def test_total_contributors_skips_missing_and_forbidden_repositories_and_contributors
    octo = Object.new
    octo.define_singleton_method(:repository) do |repo|
      raise(Octokit::NotFound) if repo == 'foo/missing'
      raise(Octokit::Forbidden) if repo == 'foo/blocked'
      { size: 1 }
    end
    octo.define_singleton_method(:contributors) do |repo|
      raise(Octokit::NotFound) if repo == 'foo/no-contributors'
      raise(Octokit::Forbidden) if repo == 'foo/no-access'
      [{ id: 10 }, { id: 11 }]
    end
    result =
      measure(
        'dimensions-of-terrain', 'total_contributors',
        %w[foo/missing foo/blocked foo/no-contributors foo/no-access foo/good], octo,
        proc do
          total_contributors(nil)
        end
      )
    assert_equal({ total_contributors: 2 }, result)
  end

  def test_total_files_skips_missing_and_forbidden_repositories_and_trees
    octo = Object.new
    octo.define_singleton_method(:repository) do |repo|
      raise(Octokit::NotFound) if repo == 'foo/missing'
      raise(Octokit::Forbidden) if repo == 'foo/blocked'
      { size: 1, default_branch: 'master' }
    end
    octo.define_singleton_method(:tree) do |repo, _branch, **|
      raise(Octokit::NotFound) if repo == 'foo/no-tree'
      raise(Octokit::Forbidden) if repo == 'foo/no-access'
      { truncated: false, tree: [{ type: 'blob' }] * 3 }
    end
    result =
      measure(
        'dimensions-of-terrain', 'total_files',
        %w[foo/missing foo/blocked foo/no-tree foo/no-access foo/good], octo,
        proc do
          total_files(nil)
        end
      )
    assert_equal({ total_files: 3 }, result)
  end

  def test_total_commits_skips_missing_and_forbidden_repositories
    octo = Object.new
    octo.define_singleton_method(:repository) do |repo|
      raise(Octokit::NotFound) if repo == 'foo/missing'
      raise(Octokit::Forbidden) if repo == 'foo/blocked'
      { size: 1, default_branch: 'master' }
    end
    graph = Object.new
    reached = nil
    graph.define_singleton_method(:total_commits) do |repos:|
      reached = repos
      [{ 'total_commits' => 7 }]
    end
    result =
      Fbe.stub(:github_graph, graph) do
        measure(
          'dimensions-of-terrain', 'total_commits',
          %w[foo/missing foo/blocked foo/good], octo,
          proc do
            total_commits(nil)
          end
        )
      end
    assert_equal([%w[foo good master]], reached, 'a skipped repository must not reach the graph')
    assert_equal({ total_commits: 7 }, result)
  end

  def test_total_commits_returns_empty_when_all_repositories_are_skipped
    octo = Object.new
    octo.define_singleton_method(:repository) do |repo|
      raise(Octokit::NotFound) if repo == 'foo/missing'
      raise(Octokit::Forbidden) if repo == 'foo/blocked'
    end
    graph = Object.new
    graph.define_singleton_method(:total_commits) { |**| raise(RuntimeError, 'the graph must not be called') }
    result =
      Fbe.stub(:github_graph, graph) do
        measure(
          'dimensions-of-terrain', 'total_commits', %w[foo/missing foo/blocked], octo,
          proc do
            total_commits(nil)
          end
        )
      end
    assert_empty(result)
  end

  def test_total_active_contributors_skips_missing_and_forbidden_searches
    fact = Factbase.new.insert
    fact.when = Time.parse('2024-09-29 21:00:00 UTC')
    searches = []
    result =
      Jp.stub(
        :qosearch,
        proc do |query, **|
          searches << query
          raise(Octokit::NotFound) if query.include?('repo:foo/missing')
          raise(Octokit::Forbidden) if query.include?('repo:foo/blocked')
          { items: [{ author: { id: 10 } }, { author: { id: 11 } }] }
        end
      ) do
        measure(
          'dimensions-of-terrain', 'total_active_contributors',
          %w[foo/missing foo/blocked foo/good], Object.new,
          proc do
            total_active_contributors(fact)
          end
        )
      end
    assert_equal({ total_active_contributors: 2 }, result)
    assert_equal(3, searches.size, 'all three repositories must be searched')
  end

  def test_total_issues_created_skips_failing_repositories
    fact = Factbase.new.insert
    fact.since = Time.parse('2024-09-01 00:00:00 UTC')
    graph = Object.new
    graph.define_singleton_method(:total_issues_created) do |_owner, name, _since|
      raise(GraphQL::Client::Error, 'GraphQL failed') if name == 'graphql'
      raise(Octokit::NotFound) if name == 'missing'
      raise(Octokit::Forbidden) if name == 'blocked'
      raise(Net::OpenTimeout, 'Timeout') if name == 'offline'
      { 'issues' => 7, 'pulls' => 5 }
    end
    result =
      Fbe.stub(:github_graph, graph) do
        measure(
          'quantity-of-deliverables', 'total_issues_created',
          %w[foo/graphql foo/missing foo/blocked foo/offline foo/good], Object.new,
          proc do
            total_issues_created(fact)
          end
        )
      end
    assert_equal({ total_issues_created: 7, total_pulls_submitted: 5 }, result)
  end

  private

  def measure(judge, metric, repos, octo, action)
    $judge = judge
    $loog = Loog::NULL
    $global = {}
    $options = Judges::Options.new({ 'repositories' => repos.join(',') })
    load(File.join(__dir__, "../../judges/#{judge}/#{metric}.rb"))
    Fbe.stub(:octo, octo) do
      Fbe.stub(:unmask_repos, proc { |&b| repos.each(&b) }) { action.call }
    end
  end
end
