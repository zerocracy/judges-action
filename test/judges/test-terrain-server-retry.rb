# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'tmpdir'
require_relative '../test__helper'

require_relative '../../judges/dimensions-of-terrain/total_commits'
require_relative '../../judges/dimensions-of-terrain/total_contributors'
require_relative '../../judges/dimensions-of-terrain/total_files'
require_relative '../../judges/dimensions-of-terrain/total_releases'
require_relative '../../judges/dimensions-of-terrain/total_stars'
require_relative '../../lib/incremate'

class TestTerrainServerRetry < Jp::Test
  def test_retries_release_total
    retry_metric(:total_releases, :releases, total_releases: [4])
  end

  def test_retries_stars_and_forks
    retry_metric(:total_stars, :repository, total_stars: [14], total_forks: [6])
  end

  def test_retries_contributor_total
    %i[repository contributors].each do |call|
      retry_metric(:total_contributors, call, total_contributors: [2])
    end
  end

  def test_retries_file_total
    %i[repository tree].each do |call|
      retry_metric(:total_files, call, total_files: [4])
    end
  end

  def test_retries_commit_total
    retry_metric(:total_commits, :repository, total_commits: [6])
  end

  private

  def retry_metric(metric, failed, expected)
    WebMock.disable_net_connect!
    previous = [$loog, $options, $global]
    $loog = Loog::NULL
    $options = Judges::Options.new
    $global = {}
    repos = %w[foo/a foo/b]
    [Octokit::BadGateway, Octokit::ServiceUnavailable].each do |error|
      failure = { active: true }
      octo = client(failed, failure, error)
      graph = Object.new
      graph.define_singleton_method(:total_commits) { |repos:| repos.map { { 'total_commits' => 3 } } }
      Fbe.stub(:octo, octo) do
        Fbe.stub(:github_graph, graph) do
          Fbe.stub(:over?, false) do
            Fbe.stub(:unmask_repos, ->(&block) { repos.each(&block) }) do
              measure(metric, Factbase.new.insert, failure, expected)
            end
          end
        end
      end
    end
  ensure
    $loog, $options, $global = previous
  end

  def measure(metric, fact, failure, expected)
    Dir.mktmpdir do |dir|
      source = File.expand_path("../../judges/dimensions-of-terrain/#{metric}.rb", __dir__)
      File.write(File.join(dir, "#{metric}.rb"), "require #{source.inspect}\n")
      File.write(File.join(dir, 'total_zzz_probe.rb'), "def total_zzz_probe(_fact) = { total_zzz_probe: 13 }\n")
      Jp.incremate(fact, dir, 'total')
      expected.each_key { |key| assert_nil(fact[key.to_s], "#{key} was frozen after a server error") }
      assert_nil(fact[Jp::INCREMATE_MARKER], 'an incomplete metric was marked complete')
      assert_equal(13, fact.total_zzz_probe, 'the other metrics must still be evaluated')
      failure[:active] = false
      Jp.incremate(fact, dir, 'total')
      expected.each { |key, values| assert_equal(values, fact[key.to_s], "#{key} did not recover both repositories") }
    end
  end

  def client(failed, failure, error)
    responses = {
      repository: { size: 1, default_branch: 'master', stargazers_count: 7, forks: 3 },
      releases: [{ draft: false }, { draft: false }],
      contributors: lambda do |repo|
        [{ id: repo == 'foo/a' ? 42 : 43 }]
      end,
      tree: { truncated: false, tree: [{ type: 'blob' }, { type: 'blob' }] }
    }
    Object.new.tap do |octo|
      responses.each do |name, value|
        octo.define_singleton_method(name) do |repo, *|
          raise(error) if failure[:active] && name == failed && repo == 'foo/b'
          value.respond_to?(:call) ? value.call(repo) : value
        end
      end
    end
  end
end
