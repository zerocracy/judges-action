# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'fbe/github_graph'
require 'fbe/unmask_repos'
require 'judges/options'
require 'loog'
require_relative '../test__helper'

class TestTotalReviewsSubmittedBots < Jp::Test
  COPILOT = 'copilot-pull-request-reviewer'
  NEXT = 'yc29yOnYyOjE'

  def two_reviews(authors = [nil, nil])
    times = ['2025-10-02 10:00:00 UTC', '2025-10-02 12:00:00 UTC']
    authors.each_with_index.map do |author, idx|
      review = { 'id' => "PRR_#{idx + 1}", 'submitted_at' => Time.parse(times[idx]) }
      review['author'] = author unless author.nil?
      review
    end
  end

  def graph_of(reviews, queried = [])
    graph = Fbe::Graph::Fake.new
    graph.define_singleton_method(:pull_requests_with_reviews) do |_owner, _name, _since, cursor:|
      {
        'pulls_with_reviews' => [{ 'id' => 'PR_1', 'number' => 7 }],
        'has_next_page' => false,
        'next_cursor' => cursor
      }
    end
    graph.define_singleton_method(:pull_request_reviews) do |_owner, _name, pulls:|
      pulls.map do |number, _cursor|
        {
          'id' => "PR_#{number}",
          'number' => number,
          'reviews' => reviews,
          'reviews_has_next_page' => false,
          'reviews_next_cursor' => nil
        }
      end
    end
    graph.define_singleton_method(:query) do |_query|
      raise(queried) if queried.is_a?(Exception)
      { 'repository' => { 'pr_7' => { 'reviews' => { 'nodes' => queried } } } }
    end
    graph
  end

  def submitted(graph, options = {})
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github(
      'https://api.github.com/repos/foo/foo',
      body: { id: 42, full_name: 'foo/foo', archived: false, size: 100 }
    )
    $global = {}
    $local = {}
    $judge = 'quantity-of-deliverables'
    $options = Judges::Options.new({ 'repositories' => 'foo/foo' }.merge(options))
    $loog = Loog::NULL
    $epoch = Time.parse('2025-10-06 21:00:00 UTC')
    $kickoff = $epoch
    fact = Factbase.new.insert
    fact.since = Time.parse('2025-09-30 00:00:00 UTC')
    fact.when = Time.parse('2025-10-06 21:00:00 UTC')
    Fbe.stub(:github_graph, graph) do
      load(File.join(__dir__, '../../judges/quantity-of-deliverables/total_reviews_submitted.rb'))
      total_reviews_submitted(fact)
    end
  end

  def test_counts_only_reviews_by_people
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github(
      'https://api.github.com/repos/foo/foo',
      body: { id: 42, full_name: 'foo/foo', archived: false, size: 100 }
    )
    graph = Fbe::Graph::Fake.new
    graph.define_singleton_method(:pull_requests_with_reviews) do |_owner, _name, _since, cursor:|
      {
        'pulls_with_reviews' => [{ 'id' => 'PR_1', 'number' => 7 }],
        'has_next_page' => false,
        'next_cursor' => cursor
      }
    end
    graph.define_singleton_method(:pull_request_reviews) do |_owner, _name, pulls:|
      pulls.map do |number, _cursor|
        {
          'id' => "PR_#{number}",
          'number' => number,
          'reviews' => [
            {
              'id' => 'PRR_1', 'submitted_at' => Time.parse('2025-10-02 10:00:00 UTC'),
              'author' => { 'login' => 'copilot-pull-request-reviewer', 'type' => 'Bot' }
            },
            {
              'id' => 'PRR_2', 'submitted_at' => Time.parse('2025-10-02 12:00:00 UTC'),
              'author' => { 'login' => 'bob', 'type' => 'User' }
            }
          ],
          'reviews_has_next_page' => false,
          'reviews_next_cursor' => nil
        }
      end
    end
    $global = {}
    $local = {}
    $judge = 'quantity-of-deliverables'
    $options = Judges::Options.new({ 'repositories' => 'foo/foo' })
    $loog = Loog::NULL
    $epoch = Time.parse('2025-10-06 21:00:00 UTC')
    $kickoff = $epoch
    fact = Factbase.new.insert
    fact.since = Time.parse('2025-09-30 00:00:00 UTC')
    fact.when = Time.parse('2025-10-06 21:00:00 UTC')
    Fbe.stub(:github_graph, graph) do
      load(File.join(__dir__, '../../judges/quantity-of-deliverables/total_reviews_submitted.rb'))
      assert_equal(
        { total_reviews_submitted: 1 }, total_reviews_submitted(fact),
        'a Copilot review is counted as a submitted code review'
      )
    end
  end

  def test_asks_github_for_the_author_of_every_review
    queries = []
    nodes = [
      { 'id' => 'PRR_1', 'author' => { 'login' => COPILOT, '__typename' => 'Bot' } },
      { 'id' => 'PRR_2', 'author' => { 'login' => 'bob', '__typename' => 'User' } }
    ]
    graph = graph_of(two_reviews, nodes)
    graph.define_singleton_method(:query) do |query|
      queries.push(query)
      { 'repository' => { 'pr_7' => { 'reviews' => { 'nodes' => nodes } } } }
    end
    assert_equal(
      { total_reviews_submitted: 1 },
      submitted(graph),
      'the author of a review is taken from the query, since fbe 0.49.1 does not return it'
    )
    assert_includes(queries.first, 'author {', 'the query must ask for the author of each review')
    assert_includes(queries.first, '__typename', 'the query must ask for the type of the author')
  end

  def test_ignores_a_login_from_the_bots_option
    assert_equal(
      { total_reviews_submitted: 1 },
      submitted(
        graph_of(
          two_reviews,
          [
            { 'id' => 'PRR_1', 'author' => { 'login' => 'coderabbitai', '__typename' => 'User' } },
            { 'id' => 'PRR_2', 'author' => { 'login' => 'bob', '__typename' => 'User' } }
          ]
        ),
        'bots' => 'CodeRabbitAI'
      ),
      'a login from the bots option is not a person, whatever the case of its letters'
    )
  end

  def test_counts_a_review_of_an_unknown_author
    assert_equal(
      { total_reviews_submitted: 2 },
      submitted(graph_of(two_reviews)),
      'a review, whose author neither fbe nor the query reports, is counted, not dropped'
    )
  end

  def test_drops_the_repository_when_the_author_query_fails
    assert_equal(
      { total_reviews_submitted: 0 },
      submitted(graph_of(two_reviews, GraphQL::Client::Error.new('GraphQL failed'))),
      'reviews of a repository, whose author query failed, are dropped, not counted as people'
    )
  end

  def test_asks_for_the_authors_of_the_next_page_too
    queries = []
    graph = Fbe::Graph::Fake.new
    graph.define_singleton_method(:pull_requests_with_reviews) do |_owner, _name, _since, cursor:|
      {
        'pulls_with_reviews' => [{ 'id' => 'PR_7', 'number' => 7 }],
        'has_next_page' => false,
        'next_cursor' => cursor
      }
    end
    page =
      lambda do |cursor|
        [
          {
            'id' => "PRR_#{cursor.nil? ? 1 : 2}",
            'submitted_at' => Time.parse('2025-10-02 10:00:00 UTC')
          }
        ]
      end
    graph.define_singleton_method(:pull_request_reviews) do |_owner, _name, pulls:|
      pulls.map do |number, cursor|
        {
          'id' => "PR_#{number}",
          'number' => number,
          'reviews' => page.call(cursor),
          'reviews_has_next_page' => cursor.nil?,
          'reviews_next_cursor' => cursor.nil? ? NEXT : nil
        }
      end
    end
    graph.define_singleton_method(:query) do |query|
      queries.push(query)
      first = !query.include?("after: \"#{NEXT}\",")
      who = first ? { 'login' => COPILOT, '__typename' => 'Bot' } : { 'login' => 'bob', '__typename' => 'User' }
      {
        'repository' => {
          'pr_7' => {
            'reviews' => {
              'nodes' => [{ 'id' => "PRR_#{first ? 1 : 2}", 'author' => who }]
            }
          }
        }
      }
    end
    assert_equal(
      { total_reviews_submitted: 1 },
      submitted(graph),
      'the review of the next page is counted, while the bot review of the first page is dropped'
    )
    assert_includes(queries.last, "after: \"#{NEXT}\",", 'the query for the next page must continue after its cursor')
  end
end
