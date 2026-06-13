# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'fbe/github_graph'
require 'fbe/unmask_repos'
require 'json'
require 'judges/options'
require 'loog'
require_relative '../test__helper'

class TestQuantityOfDeliverables < Jp::Test
  using SmartFactbase

  def reviewgraph(repo, call, err)
    graph = Fbe::Graph::Fake.new
    pulls = graph.method(:pull_requests_with_reviews)
    reviews = graph.method(:pull_request_reviews)
    graph.define_singleton_method(:pull_requests_with_reviews) do |owner, name, since, cursor:|
      raise(err) if repo == "#{owner}/#{name}" && call == :pulls
      pulls.call(owner, name, since, cursor:)
    end
    graph.define_singleton_method(:pull_request_reviews) do |owner, name, pulls:|
      raise(err) if repo == "#{owner}/#{name}" && call == :reviews
      reviews.call(owner, name, pulls:)
    end
    graph
  end

  def directreviews(repos, graph)
    WebMock.disable_net_connect!
    rate_limit_up
    repos.each_with_index do |repo, idx|
      stub_github(
        "https://api.github.com/repos/#{repo}",
        body: { id: 100 + idx, full_name: repo, open_issues: 0, archived: false, size: 100 }
      )
    end
    $global = {}
    $local = {}
    $judge = 'quantity-of-deliverables'
    $options = Judges::Options.new({ 'repositories' => repos.join(',') })
    $loog = Loog::NULL
    $epoch = Time.parse('2025-10-06 21:00:00 UTC')
    $kickoff = $epoch
    fact = Factbase.new.insert
    fact.since = Time.parse('2025-09-30 00:00:00 +03:00')
    fact.when = Time.parse('2025-10-06 21:00:00 UTC')
    Fbe.stub(:github_graph, graph) do
      load(File.join(__dir__, '../../judges/quantity-of-deliverables/total_reviews_submitted.rb'))
      total_reviews_submitted(fact)
    end
  end

  def test_counts_commits
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{"rate":{"remaining":222}}', headers: { 'X-RateLimit-Remaining' => '222' } }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo',
      body: { id: 42, full_name: 'foo/foo', open_issues: 0, size: 10 }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/actions/runs?created=2024-07-11..2024-08-12&per_page=1',
      body: { total_count: 0, workflow_runs: [] }
    )
    fb = Factbase.new
    Fbe.stub(:github_graph, Fbe::Graph::Fake.new) do
      Time.stub(:now, Time.parse('2024-08-12 21:00:00 UTC')) do
        load_it('quantity-of-deliverables', fb)
        f = fb.query("(eq what 'quantity-of-deliverables')").each.to_a
        assert_equal(29, f.first.total_commits_pushed)
        assert_equal(1857, f.first.total_hoc_committed)
        assert_equal(25, f.first.total_issues_created)
        assert_equal(8, f.first.total_pulls_submitted)
      end
    end
  end

  def test_processes_empty_repository
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{"rate":{"remaining":222}}', headers: { 'X-RateLimit-Remaining' => '222' } }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo',
      body: { id: 42, full_name: 'foo/foo', open_issues: 0, size: 0 }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/actions/runs?created=2024-07-11..2024-08-12&per_page=1',
      body: { total_count: 0, workflow_runs: [] }
    )
    fb = Factbase.new
    Fbe.stub(:github_graph, Fbe::Graph::Fake.new) do
      Time.stub(:now, Time.parse('2024-08-12 21:00:00 UTC')) do
        load_it('quantity-of-deliverables', fb)
        f = fb.query("(eq what 'quantity-of-deliverables')").each.to_a
        assert_equal(0, f.first.total_commits_pushed)
        assert_equal(0, f.first.total_hoc_committed)
        assert_equal(25, f.first.total_issues_created)
        assert_equal(8, f.first.total_pulls_submitted)
      end
    end
  end

  def test_total_commits_pushed_skips_unavailable
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repos/foo/missing', status: 404, body: { message: 'Not Found' })
    stub_github('https://api.github.com/repos/foo/blocked', status: 403, body: { message: 'Forbidden' })
    stub_github(
      'https://api.github.com/repos/foo/good',
      body: { id: 42, full_name: 'foo/good', open_issues: 0, size: 100 }
    )
    graph = Object.new
    graph.define_singleton_method(:total_commits_pushed) do |_owner, name, _since|
      { 'commits' => name.length, 'hoc' => name.length * 100 }
    end
    fact = Object.new
    fact.define_singleton_method(:since) { Time.parse('2025-10-01 00:00:00 UTC') }
    unmask = proc { |&block| %w[foo/missing foo/blocked foo/good].each { |repo| block.call(repo) } }
    $global = {}
    $judge = 'quantity-of-deliverables'
    $loog = Loog::NULL
    $options = Judges::Options.new({ 'repositories' => 'foo/foo' })
    Fbe.stub(:unmask_repos, unmask) do
      Fbe.stub(:github_graph, graph) do
        load(File.join(__dir__, '../../judges/quantity-of-deliverables/total_commits_pushed.rb'))
        assert_equal({ total_commits_pushed: 4, total_hoc_committed: 400 }, total_commits_pushed(fact))
      end
    end
  end

  def test_total_commits_pushed_skips_graph_failures
    WebMock.disable_net_connect!
    rate_limit_up
    %w[bad good].each do |name|
      stub_github(
        "https://api.github.com/repos/foo/#{name}",
        body: { id: 42, full_name: "foo/#{name}", open_issues: 0, size: 100 }
      )
    end
    graph = Object.new
    graph.define_singleton_method(:total_commits_pushed) do |owner, name, _since|
      repo = "#{owner}/#{name}"
      raise(Net::OpenTimeout, 'timeout') if repo == 'foo/bad'
      { 'commits' => name.length, 'hoc' => name.length * 100 }
    end
    fact = Object.new
    fact.define_singleton_method(:since) { Time.parse('2025-10-01 00:00:00 UTC') }
    unmask = proc { |&block| %w[foo/bad foo/good].each { |repo| block.call(repo) } }
    $global = {}
    $judge = 'quantity-of-deliverables'
    $loog = Loog::NULL
    $options = Judges::Options.new({ 'repositories' => 'foo/foo' })
    Fbe.stub(:unmask_repos, unmask) do
      Fbe.stub(:github_graph, graph) do
        load(File.join(__dir__, '../../judges/quantity-of-deliverables/total_commits_pushed.rb'))
        assert_equal({ total_commits_pushed: 4, total_hoc_committed: 400 }, total_commits_pushed(fact))
      end
    end
  end

  def test_total_commits_pushed_keeps_code_errors
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github(
      'https://api.github.com/repos/foo/bad',
      body: { id: 42, full_name: 'foo/bad', open_issues: 0, size: 100 }
    )
    graph = Object.new
    graph.define_singleton_method(:total_commits_pushed) do |_owner, _name, _since|
      raise(NoMethodError, 'unexpected')
    end
    fact = Object.new
    fact.define_singleton_method(:since) { Time.parse('2025-10-01 00:00:00 UTC') }
    unmask = proc { |&block| block.call('foo/bad') }
    $global = {}
    $judge = 'quantity-of-deliverables'
    $loog = Loog::NULL
    $options = Judges::Options.new({ 'repositories' => 'foo/foo' })
    Fbe.stub(:unmask_repos, unmask) do
      Fbe.stub(:github_graph, graph) do
        load(File.join(__dir__, '../../judges/quantity-of-deliverables/total_commits_pushed.rb'))
        assert_raises(NoMethodError) { total_commits_pushed(fact) }
      end
    end
  end

  def test_releases_published_skips_graph_failures
    WebMock.disable_net_connect!
    graph = Object.new
    graph.define_singleton_method(:total_releases_published) do |_owner, name, _since|
      raise(Net::OpenTimeout, 'timeout') if name == 'bad'
      { 'releases' => name.length }
    end
    unmask =
      lambda do |&block|
        repos = ['foo/bad', 'foo/good']
        if block
          repos.each { |repo| block.call(repo) }
        else
          repos
        end
      end
    fact = Object.new
    fact.define_singleton_method(:since) { Time.parse('2025-10-01 00:00:00 UTC') }
    $global = {}
    $judge = 'quantity-of-deliverables'
    $loog = Loog::NULL
    Fbe.stub(:unmask_repos, unmask) do
      Fbe.stub(:github_graph, graph) do
        load(File.join(__dir__, '../../judges/quantity-of-deliverables/total_releases_published.rb'))
        assert_equal({ total_releases_published: 4 }, total_releases_published(fact))
      end
    end
  end

  def test_releases_published_keeps_code_errors
    WebMock.disable_net_connect!
    graph = Object.new
    graph.define_singleton_method(:total_releases_published) do |_owner, _name, _since|
      raise(NoMethodError, 'unexpected')
    end
    fact = Object.new
    fact.define_singleton_method(:since) { Time.parse('2025-10-01 00:00:00 UTC') }
    unmask = proc { |&block| block.call('foo/bad') }
    $global = {}
    $judge = 'quantity-of-deliverables'
    $loog = Loog::NULL
    Fbe.stub(:unmask_repos, unmask) do
      Fbe.stub(:github_graph, graph) do
        load(File.join(__dir__, '../../judges/quantity-of-deliverables/total_releases_published.rb'))
        assert_raises(NoMethodError) { total_releases_published(fact) }
      end
    end
  end

  def test_total_releases_published
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{"rate":{"remaining":222}}', headers: { 'X-RateLimit-Remaining' => '222' } }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo',
      body: { id: 42, full_name: 'foo/foo', open_issues: 0, size: 100 }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/actions/runs?created=2024-08-02..2024-08-09&per_page=1',
      body: { total_count: 0, workflow_runs: [] }
    )
    fb = Factbase.new
    f = fb.insert
    f.what = 'pmp'
    f.area = 'scope'
    f.qod_days = 7
    Fbe.stub(:github_graph, Fbe::Graph::Fake.new) do
      Time.stub(:now, Time.parse('2024-08-09 21:00:00 UTC')) do
        load_it('quantity-of-deliverables', fb)
        f = fb.query('(eq what "quantity-of-deliverables")').each.first
        assert_equal(Time.parse('2024-08-03 00:00:00 +03:00'), f.since)
        assert_equal(Time.parse('2024-08-09 21:00:00 UTC'), f.when)
        assert_equal(7, f.total_releases_published)
      end
    end
  end

  def test_deliverables_total_releases
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{"rate":{"remaining":222}}', headers: { 'X-RateLimit-Remaining' => '222' } }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo',
      body: { id: 42, full_name: 'foo/foo', open_issues: 0, size: 100 }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/actions/runs?created=2024-08-02..2024-08-09&per_page=1',
      body: { total_count: 0, workflow_runs: [] }
    )
    fb = Factbase.new
    f = fb.insert
    f.what = 'pmp'
    f.area = 'scope'
    f.qod_days = 7
    Fbe.stub(:github_graph, Fbe::Graph::Fake.new) do
      Time.stub(:now, Time.parse('2024-08-09 21:00:00 UTC')) do
        load_it('quantity-of-deliverables', fb)
        f = fb.query('(eq what "quantity-of-deliverables")').each.first
        assert_equal(Time.parse('2024-08-03 00:00:00 +03:00'), f.since)
        assert_equal(Time.parse('2024-08-09 21:00:00 UTC'), f.when)
        assert_equal(7, f.total_releases_published)
      end
    end
  end

  def test_total_reviews_submitted
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{"rate":{"remaining":222}}', headers: { 'X-RateLimit-Remaining' => '222' } }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo',
      body: { id: 42, full_name: 'foo/foo', open_issues: 0, size: 100 }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/actions/runs?created=2025-09-29..2025-10-06&per_page=1',
      body: {
        total_count: 0,
        workflow_runs: []
      }
    )
    fb = Factbase.new
    f = fb.insert
    f.what = 'pmp'
    f.area = 'scope'
    f.qod_days = 7
    Fbe.stub(:github_graph, Fbe::Graph::Fake.new) do
      Time.stub(:now, Time.parse('2025-10-06 21:00:00 UTC')) do
        load_it('quantity-of-deliverables', fb)
        f = fb.query('(eq what "quantity-of-deliverables")').each.first
        assert_equal(Time.parse('2025-09-30 00:00:00 +03:00'), f.since)
        assert_equal(Time.parse('2025-10-06 21:00:00 UTC'), f.when)
        assert_equal(4, f.total_reviews_submitted)
      end
    end
  end

  def test_total_reviews_submitted_excludes_after
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{"rate":{"remaining":222}}', headers: { 'X-RateLimit-Remaining' => '222' } }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo',
      body: { id: 42, full_name: 'foo/foo', open_issues: 0, size: 100 }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/actions/runs?created=2025-09-26..2025-10-03&per_page=1',
      body: {
        total_count: 0,
        workflow_runs: []
      }
    )
    fb = Factbase.new
    f = fb.insert
    f.what = 'pmp'
    f.area = 'scope'
    f.qod_days = 7
    Fbe.stub(:github_graph, Fbe::Graph::Fake.new) do
      Time.stub(:now, Time.parse('2025-10-03 00:00:00 UTC')) do
        load_it('quantity-of-deliverables', fb)
        f = fb.query('(eq what "quantity-of-deliverables")').each.first
        assert_equal(
          2, f.total_reviews_submitted,
          'reviews submitted on 2025-10-03 15:58:42 UTC and 2025-10-04 15:58:42 UTC ' \
          'must be excluded (after fact.when 2025-10-03 00:00:00 UTC); ' \
          'only the two 2025-10-02 reviews should be counted'
        )
      end
    end
  end

  def test_total_reviews_submitted_skips_pull_list
    graph = reviewgraph('foo/bad', :pulls, GraphQL::Client::Error.new('GraphQL failed'))
    assert_equal({ total_reviews_submitted: 4 }, directreviews(%w[foo/bad foo/good], graph))
  end

  def test_total_reviews_submitted_skips_reviews
    graph = reviewgraph('foo/bad', :reviews, GraphQL::Client::Error.new('GraphQL failed'))
    assert_equal({ total_reviews_submitted: 4 }, directreviews(%w[foo/bad foo/good], graph))
  end

  def test_total_reviews_submitted_keeps_code_errors
    graph = reviewgraph('foo/bad', :pulls, NoMethodError.new('bad fake'))
    assert_raises(NoMethodError) { directreviews(%w[foo/bad], graph) }
  end

  def test_quantity_of_deliverables_total_builds_ran
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{"rate":{"remaining":222}}', headers: { 'X-RateLimit-Remaining' => '222' } }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo',
      body: { id: 42, full_name: 'foo/foo', open_issues: 0, size: 100 }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/actions/runs?created=2024-08-02..2024-08-09&per_page=1',
      body: {
        total_count: 3,
        workflow_runs: [
          {
            id: 710,
            display_title: 'some title',
            run_number: 2615,
            event: 'dynamic',
            status: 'completed',
            conclusion: 'success',
            workflow_id: 141
          }
        ]
      }
    )
    fb = Factbase.new
    f = fb.insert
    f.what = 'pmp'
    f.area = 'scope'
    f.qod_days = 7
    Fbe.stub(:github_graph, Fbe::Graph::Fake.new) do
      Time.stub(:now, Time.parse('2024-08-09 21:00:00 UTC')) do
        load_it('quantity-of-deliverables', fb)
        f = fb.query('(eq what "quantity-of-deliverables")').each.first
        assert_equal(Time.parse('2024-08-03 00:00:00 +03:00'), f.since)
        assert_equal(Time.parse('2024-08-09 21:00:00 UTC'), f.when)
        assert_equal(3, f.total_builds_ran)
      end
    end
  end

  def test_quantity_of_deliverables_fix_gap
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github(
      'https://api.github.com/repos/foo/foo',
      body: { id: 42, full_name: 'foo/foo', open_issues: 0, size: 100 }
    )
    [
      %w[2025-09-01 2025-09-05],
      %w[2025-09-05 2025-09-15],
      %w[2025-09-15 2025-09-25]
    ].each do |since, upper|
      stub_github(
        "https://api.github.com/repos/foo/foo/actions/runs?created=#{since}..#{upper}&per_page=1",
        body: {
          total_count: 0,
          workflow_runs: []
        }
      )
    end
    fb = Factbase.new
    f = fb.insert
    f.what = 'pmp'
    f.area = 'scope'
    f.qod_days = 7
    fb.with(
      _id: 1, what: 'quantity-of-deliverables',
      since: Time.parse('2025-09-01 15:00:00 UTC'), when: Time.parse('2025-09-05 15:00:00 UTC')
    ).with(
      _id: 2, what: 'quantity-of-deliverables',
      since: Time.parse('2025-09-15 15:00:00 UTC'), when: Time.parse('2025-09-25 15:00:00 UTC')
    )
    Fbe.stub(:github_graph, Fbe::Graph::Fake.new) do
      Time.stub(:now, Time.parse('2025-09-20 15:00:00 UTC')) do
        load_it('quantity-of-deliverables', fb)
        assert(
          fb.one?(
            what: 'quantity-of-deliverables',
            since: Time.parse('2025-09-05 15:00:00 UTC'),
            when: Time.parse('2025-09-15 15:00:00 UTC')
          )
        )
      end
    end
  end
end
