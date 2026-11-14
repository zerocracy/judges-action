# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'judges/options'
require 'loog'
require_relative '../test__helper'

class TestQuantityGraphqlErrors < Jp::Test
  def test_moves_on_when_the_graph_refuses
    $judge = 'quantity-of-deliverables'
    $loog = Loog::NULL
    $global = {}
    $options = Judges::Options.new({ 'repositories' => 'foo/foo' })
    fact = Factbase.new.insert
    fact.since = Time.parse('2025-01-01 00:00:00 UTC')
    fact.when = Time.parse('2025-02-01 00:00:00 UTC')
    graph = Object.new
    %i[total_issues_created total_releases_published pull_requests_with_reviews total_commits_pushed].each do |m|
      graph.define_singleton_method(m) { |*, **| raise(Fbe::Error, "Repository 'foo/foo' not found") }
    end
    {
      'total_issues_created' => { total_issues_created: 0, total_pulls_submitted: 0 },
      'total_releases_published' => { total_releases_published: 0 },
      'total_reviews_submitted' => { total_reviews_submitted: 0 }
    }.each do |name, expected|
      load(File.join(__dir__, "../../judges/quantity-of-deliverables/#{name}.rb"))
      result =
        Fbe.stub(:github_graph, graph) do
          Fbe.stub(:unmask_repos, proc { |&b| b.nil? ? ['foo/foo'] : b.call('foo/foo') }) { __send__(name, fact) }
        end
      assert_equal(expected, result, name)
    end
  end
end
