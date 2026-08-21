# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'fbe/github_graph'
require_relative '../../lib/closing_issues'
require_relative '../test__helper'

class TestClosingIssues < Jp::Test
  def test_collects_assignees_of_every_closed_issue
    $loog = Loog::NULL
    graph =
      Class.new(Fbe::Graph::Fake) do
        define_method(:query) do |_qry|
          {
            'repository' => {
              'pullRequest' => {
                'closingIssuesReferences' => {
                  'pageInfo' => { 'hasNextPage' => false, 'endCursor' => nil },
                  'nodes' => [
                    { 'number' => 8_211, 'assignees' => { 'nodes' => [{ 'databaseId' => 90_223 }] } },
                    { 'number' => 8_212, 'assignees' => { 'nodes' => [] } }
                  ]
                }
              }
            }
          }
        end
      end.new
    Fbe.stub(:github_graph, graph) do
      assert_equal(
        { 8_211 => [90_223], 8_212 => [] },
        Jp.closing_issues('zerocracy/foo', 7_142),
        'assignees of the closed issues dont reach the caller'
      )
    end
  end

  def test_collects_many_assignees_of_one_closed_issue
    $loog = Loog::NULL
    graph =
      Class.new(Fbe::Graph::Fake) do
        define_method(:query) do |_qry|
          {
            'repository' => {
              'pullRequest' => {
                'closingIssuesReferences' => {
                  'pageInfo' => { 'hasNextPage' => false, 'endCursor' => nil },
                  'nodes' => [
                    {
                      'number' => 511,
                      'assignees' => { 'nodes' => [{ 'databaseId' => 62 }, { 'databaseId' => 4_009 }] }
                    }
                  ]
                }
              }
            }
          }
        end
      end.new
    Fbe.stub(:github_graph, graph) do
      assert_equal(
        { 511 => [62, 4_009] },
        Jp.closing_issues('zerocracy/foo', 512),
        'both assignees of one closed issue are not collected'
      )
    end
  end

  def test_walks_through_every_page_of_closed_issues
    $loog = Loog::NULL
    graph =
      Class.new(Fbe::Graph::Fake) do
        define_method(:query) do |qry|
          nodes =
            if qry.include?('after: "cur-77"')
              [{ 'number' => 78, 'assignees' => { 'nodes' => [{ 'databaseId' => 22 }] } }]
            else
              [{ 'number' => 77, 'assignees' => { 'nodes' => [{ 'databaseId' => 21 }] } }]
            end
          {
            'repository' => {
              'pullRequest' => {
                'closingIssuesReferences' => {
                  'pageInfo' => {
                    'hasNextPage' => !qry.include?('after: "cur-77"'),
                    'endCursor' => 'cur-77'
                  },
                  'nodes' => nodes
                }
              }
            }
          }
        end
      end.new
    Fbe.stub(:github_graph, graph) do
      assert_equal(
        { 77 => [21], 78 => [22] },
        Jp.closing_issues('zerocracy/foo', 79),
        'the second page of closed issues is not fetched'
      )
    end
  end

  def test_finds_nothing_when_pull_closes_no_issue
    $loog = Loog::NULL
    Fbe.stub(:github_graph, Fbe::Graph::Fake.new) do
      assert_empty(
        Jp.closing_issues('zerocracy/foo', 4_242),
        'a pull request that closes nothing does not yield an empty hash'
      )
    end
  end

  def test_cannot_read_closing_issues_when_access_is_forbidden
    $loog = Loog::NULL
    graph =
      Class.new(Fbe::Graph::Fake) do
        define_method(:query) do |_qry|
          raise(Octokit::Forbidden.new(method: :get, url: 'https://api.github.com', status: 403, body: 'Forbidden'))
        end
      end.new
    Fbe.stub(:github_graph, graph) do
      assert_nil(Jp.closing_issues('zerocracy/foo', 313), 'a forbidden pull request is not reported as unknown')
    end
  end

  def test_cannot_read_closing_issues_when_graph_breaks
    $loog = Loog::NULL
    graph =
      Class.new(Fbe::Graph::Fake) do
        define_method(:query) do |_qry|
          raise(GraphQL::Client::Error, 'GraphQL is down')
        end
      end.new
    Fbe.stub(:github_graph, graph) do
      assert_nil(Jp.closing_issues('zerocracy/foo', 909), 'a broken GraphQL call is not reported as unknown')
    end
  end

  def test_marks_every_assignee_of_every_closed_issue
    fact = Factbase.new.insert
    Jp.fill_hijacks(fact, { 71 => [800], 72 => [801, 802] }, 4_242)
    assert_equal([800, 801, 802], fact['assignee'], 'not all assignees of the closed issues are marked')
  end

  def test_counts_one_hijack_per_issue_assigned_to_somebody_else
    fact = Factbase.new.insert
    Jp.fill_hijacks(fact, { 71 => [800], 72 => [801], 73 => [] }, 4_242)
    assert_equal(2, fact.hijacks, 'the issues taken from other people are miscounted')
  end

  def test_counts_no_hijack_when_the_author_is_among_the_assignees
    fact = Factbase.new.insert
    Jp.fill_hijacks(fact, { 71 => [800, 4_242] }, 4_242)
    assert_equal(0, fact.hijacks, 'an author assigned together with somebody else is punished anyway')
  end
end
