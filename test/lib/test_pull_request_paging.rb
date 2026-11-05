# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'judges/options'
require 'loog'
require_relative '../../lib/pull_request'
require_relative '../test__helper'

class TestPullRequestPaging < Jp::Test
  def test_stops_when_the_cursor_does_not_move
    WebMock.disable_net_connect!
    rate_limit_up
    $options = Judges::Options.new({})
    $global = {}
    $loog = Loog::NULL
    stub_github('https://api.github.com/repos/foo/foo/pulls/6/comments?per_page=100', body: [])
    stub_github('https://api.github.com/repos/foo/foo/issues/6/comments?per_page=100', body: [])
    asked = 0
    graph = Object.new
    graph.define_singleton_method(:query) do |_q|
      asked += 1
      raise(RuntimeError, 'the paging loop never stopped') if asked > 5
      {
        'repository' => {
          'pullRequest' => {
            'reviewThreads' => {
              'pageInfo' => { 'hasNextPage' => true, 'endCursor' => nil },
              'nodes' => [{ 'isResolved' => true }]
            }
          }
        }
      }
    end
    Fbe.stub(:github_graph, graph) do
      pr = { number: 6, user: { id: 5 }, base: { repo: { full_name: 'foo/foo' } } }
      assert_equal(
        1, Jp.comments_info(pr)[:comments_resolved],
        'a page that gives no cursor must end the walk, not repeat itself'
      )
    end
  end
end
