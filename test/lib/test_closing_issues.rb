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
                    { 'id' => 'I_one', 'number' => 42, 'assignees' => { 'nodes' => [{ 'databaseId' => 90_223 }] } },
                    { 'id' => 'I_two', 'number' => 42, 'assignees' => { 'nodes' => [] } }
                  ]
                }
              }
            }
          }
        end
      end.new
    Fbe.stub(:github_graph, graph) do
      assert_equal(
        { 'I_one' => [90_223], 'I_two' => [] },
        Jp.closing_issues('zerocracy/foo', 7_142),
        'assignees of the closed issues dont reach the caller'
      )
    end
  end

  def test_discards_incomplete_second_page
    graph = Class.new(Fbe::Graph::Fake) do
      def query(request)
        return {} if request.include?('after:')
        {
          'repository' => {
            'pullRequest' => {
              'closingIssuesReferences' => {
                'pageInfo' => { 'hasNextPage' => true, 'endCursor' => 'next' },
                'nodes' => [{ 'id' => 'I_first', 'assignees' => { 'nodes' => [{ 'databaseId' => 42 }] } }]
              }
            }
          }
        }
      end
    end.new
    Fbe.stub(:github_graph, graph) do
      assert_nil(Jp.closing_issues('zerocracy/foo', 79), 'a partial result must remain unknown')
    end
  end

  def test_defers_assessment_when_an_assigned_pull_has_no_known_author
    fact = Factbase.new.insert
    Jp.fill_hijacks(fact, { 'I_issue' => [421] }, nil)
    refute_includes(fact.all_properties, 'hijacks', 'a missing author must not be classified')
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
                      'id' => 511,
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
              [{ 'id' => 78, 'assignees' => { 'nodes' => [{ 'databaseId' => 22 }] } }]
            else
              [{ 'id' => 77, 'assignees' => { 'nodes' => [{ 'databaseId' => 21 }] } }]
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

  def test_treats_missing_connection_as_unknown
    $loog = Loog::NULL
    Fbe.stub(:github_graph, Fbe::Graph::Fake.new) do
      assert_nil(Jp.closing_issues('zerocracy/foo', 4_242), 'missing data must remain unknown')
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
