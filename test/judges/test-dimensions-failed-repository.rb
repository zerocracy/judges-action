# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'judges/options'
require 'loog'
require_relative '../test__helper'

class TestDimensionsFailedRepository < Jp::Test
  def setup
    super
    $judge = 'dimensions-of-terrain'
    $loog = Loog::Buffer.new
    $global = {}
    $local = {}
    $options = Judges::Options.new({ 'repositories' => 'foo/good,foo/bad' })
    $epoch = Time.now
    $kickoff = Time.now
  end

  def test_drops_total_stars_when_one_repository_is_forbidden
    octo = Object.new
    octo.define_singleton_method(:repository) do |repo|
      raise(Octokit::Forbidden) if repo == 'foo/bad'
      { stargazers_count: 4, forks: 2 }
    end
    load_metric('total_stars')
    assert_empty(scan(octo) { total_stars(nil) })
    assert_includes($loog.to_s, 'will retry next cycle')
  end

  def test_keeps_total_stars_when_one_repository_is_absent
    octo = Object.new
    octo.define_singleton_method(:repository) do |repo|
      raise(Octokit::NotFound) if repo == 'foo/bad'
      { stargazers_count: 4, forks: 2 }
    end
    load_metric('total_stars')
    assert_equal({ total_stars: 4, total_forks: 2 }, scan(octo) { total_stars(nil) })
  end

  def test_drops_total_releases_when_one_repository_is_forbidden
    octo = Object.new
    octo.define_singleton_method(:releases) do |repo|
      raise(Octokit::Forbidden) if repo == 'foo/bad'
      [{ draft: false }]
    end
    load_metric('total_releases')
    assert_empty(scan(octo) { total_releases(nil) })
  end

  def test_drops_total_contributors_when_one_repository_is_forbidden
    octo = Object.new
    octo.define_singleton_method(:repository) { |_repo| { size: 10 } }
    octo.define_singleton_method(:contributors) do |repo|
      raise(Octokit::Forbidden) if repo == 'foo/bad'
      [{ id: 7 }]
    end
    load_metric('total_contributors')
    assert_empty(scan(octo) { total_contributors(nil) })
  end

  def test_drops_total_files_when_one_repository_is_forbidden
    octo = Object.new
    octo.define_singleton_method(:repository) do |repo|
      raise(Octokit::Forbidden) if repo == 'foo/bad'
      { size: 10, default_branch: 'master' }
    end
    octo.define_singleton_method(:tree) { |_repo, _branch, **| { truncated: false, tree: [{ type: 'blob' }] } }
    load_metric('total_files')
    assert_empty(scan(octo) { total_files(nil) })
  end

  def test_drops_total_commits_when_one_repository_is_forbidden
    octo = Object.new
    octo.define_singleton_method(:repository) do |repo|
      raise(Octokit::Forbidden) if repo == 'foo/bad'
      { size: 10, default_branch: 'master' }
    end
    graph = Object.new
    graph.define_singleton_method(:total_commits) { |*, **| [{ 'total_commits' => 9 }] }
    load_metric('total_commits')
    result =
      Fbe.stub(:github_graph, graph) do
        scan(octo) { total_commits(nil) }
      end
    assert_empty(result)
  end

  def test_drops_total_active_contributors_when_one_search_is_forbidden
    fact = Factbase.new.insert
    fact.when = Time.parse('2024-09-01 00:00:00 UTC')
    search =
      proc do |query, **|
        raise(Octokit::Forbidden) if query.include?('foo/bad')
        { items: [{ author: { id: 1 } }] }
      end
    load_metric('total_active_contributors')
    result =
      Fbe.stub(:unmask_repos, proc { |&block| %w[foo/good foo/bad].each { |repo| block.call(repo) } }) do
        Jp.stub(:qosearch, search) { total_active_contributors(fact) }
      end
    assert_empty(result)
  end

  private

  def load_metric(name)
    load(File.join(__dir__, "../../judges/dimensions-of-terrain/#{name}.rb"))
  end

  def scan(octo, &)
    Fbe.stub(:octo, octo) do
      Fbe.stub(:unmask_repos, proc { |&block| %w[foo/good foo/bad].each { |repo| block.call(repo) } }, &)
    end
  end
end
