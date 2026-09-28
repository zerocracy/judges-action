# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'judges/options'
require 'loog'
require_relative '../test__helper'

class TestTerrainNetworkErrors < Jp::Test
  def test_metrics_skip_repository_after_network_error
    $judge = 'dimensions-of-terrain'
    $loog = Loog::NULL
    repos = %w[foo/broken foo/good]
    unmask = proc { |&block| repos.each { |repo| block.call(repo) } }

    repository = Object.new
    repository.define_singleton_method(:repository) do |repo|
      raise Net::OpenTimeout if repo == 'foo/broken'
      { size: 10, default_branch: 'master', stargazers_count: 7, forks: 2 }
    end
    load(File.join(__dir__, '../../judges/dimensions-of-terrain/total_stars.rb'))
    result = Fbe.stub(:octo, repository) { Fbe.stub(:unmask_repos, unmask) { total_stars(nil) } }
    assert_equal({ total_stars: 7, total_forks: 2 }, result)

    contributors = Object.new
    contributors.define_singleton_method(:repository) { |_repo| { size: 10 } }
    contributors.define_singleton_method(:contributors) do |repo|
      raise Net::ReadTimeout if repo == 'foo/broken'
      [{ id: 42 }]
    end
    load(File.join(__dir__, '../../judges/dimensions-of-terrain/total_contributors.rb'))
    result = Fbe.stub(:octo, contributors) { Fbe.stub(:unmask_repos, unmask) { total_contributors(nil) } }
    assert_equal({ total_contributors: 1 }, result)

    tree = Object.new
    tree.define_singleton_method(:repository) { |_repo| { size: 10, default_branch: 'master' } }
    tree.define_singleton_method(:tree) do |repo, _branch, **|
      raise SocketError if repo == 'foo/broken'
      { truncated: false, tree: [{ type: 'blob' }] }
    end
    load(File.join(__dir__, '../../judges/dimensions-of-terrain/total_files.rb'))
    result = Fbe.stub(:octo, tree) { Fbe.stub(:unmask_repos, unmask) { total_files(nil) } }
    assert_equal({ total_files: 1 }, result)

    releases = Object.new
    releases.define_singleton_method(:releases) do |repo|
      raise Errno::ECONNRESET if repo == 'foo/broken'
      [{ draft: false }]
    end
    load(File.join(__dir__, '../../judges/dimensions-of-terrain/total_releases.rb'))
    result = Fbe.stub(:octo, releases) { Fbe.stub(:unmask_repos, unmask) { total_releases(nil) } }
    assert_equal({ total_releases: 1 }, result)

    fact = Struct.new(:when).new(Time.utc(2026, 9, 28))
    load(File.join(__dir__, '../../judges/dimensions-of-terrain/total_active_contributors.rb'))
    search = lambda do |query, method:|
      raise Net::OpenTimeout if query.include?('foo/broken')
      { items: [{ author: { id: 42 } }] }
    end
    result = Fbe.stub(:unmask_repos, unmask) { Jp.stub(:qosearch, search) { total_active_contributors(fact) } }
    assert_equal({ total_active_contributors: 1 }, result)
  end
end
