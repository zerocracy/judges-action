# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'judges/options'
require 'loog'
require_relative '../../lib/pull_request'
require_relative '../fake_github'
require_relative '../test__helper'

class TestResolvedReviewThreads < Jp::Test
  def test_counts_only_resolved_threads
    assert_equal(1, resolved { threads([{ 'isResolved' => false }, { 'isResolved' => true }]) })
  end

  def test_handles_missing_nodes
    assert_equal(0, resolved { threads(nil) })
  end

  def test_handles_a_missing_pull_request
    assert_equal(0, resolved { raise(Octokit::NotFound) })
  end

  def test_handles_a_deprecated_resource
    assert_equal(0, resolved { raise(Octokit::Deprecated) })
  end

  private

  def threads(nodes)
    { 'repository' => { 'pullRequest' => { 'reviewThreads' => { 'nodes' => nodes } } } }
  end

  def resolved
    $options = Judges::Options.new({})
    $global = {}
    $loog = Loog::NULL
    graph = Object.new
    graph.define_singleton_method(:query) { |_query| yield }
    pr = { number: 6, user: { id: 5 }, base: { repo: { full_name: 'foo/foo' } } }
    Jp::FakeGithub.new(
      'GET /rate_limit' => { rate: { remaining: 1000, limit: 1000 } },
      'GET /repos/foo/foo/pulls/6/comments?per_page=100' => [],
      'GET /repos/foo/foo/issues/6/comments?per_page=100' => []
    ).run do
      Fbe.stub(:github_graph, graph) { Jp.comments_info(pr).fetch(:comments_resolved, 0) }
    end
  end
end
