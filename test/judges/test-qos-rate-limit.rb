# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'judges/options'
require 'loog'
require 'octokit'
require_relative '../../judges/quality-of-service/some_build_success_rate'
require_relative '../../judges/quality-of-service/some_pull_hoc_size'
require_relative '../../judges/quality-of-service/some_release_hoc_size'
require_relative '../../judges/quality-of-service/some_release_interval'
require_relative '../../judges/quality-of-service/some_review_time'
require_relative '../../judges/quality-of-service/some_triage_time'
require_relative '../../lib/recovered'
require_relative '../test__helper'

class TestQosRateLimit < Jp::Test
  def setup
    super
    $judge = 'quality-of-service'
    $loog = Loog::NULL
    $global = {}
    $options = Judges::Options.new({ 'repositories' => 'foo/foo' })
  end

  def test_pull_hoc_size_stops_after_the_first_refusal
    octo, asked = refusing(:pull_request)
    found = { total_count: 5, items: (1..5).map { |number| { number: } } }
    result = measure(octo, search: found) { some_pull_hoc_size(fact) }
    assert_equal([['foo/foo', 1]], asked)
    assert_empty(result)
  end

  def test_release_interval_stops_after_the_first_repository
    octo, asked = refusing(:releases)
    result = measure(octo, repos: %w[foo/a foo/b foo/c]) { some_release_interval(fact) }
    assert_equal([['foo/a']], asked)
    assert_empty(result)
  end

  def test_release_hoc_size_stops_while_listing_releases
    octo, asked = refusing(:releases)
    result = measure(octo, repos: %w[foo/a foo/b]) { some_release_hoc_size(fact) }
    assert_equal([['foo/a']], asked)
    assert_empty(result)
  end

  def test_release_hoc_size_stops_while_comparing_tags
    octo = client
    octo.define_singleton_method(:releases) do |_repo|
      [
        { tag_name: 'v2', published_at: Time.parse('2024-08-08 00:00:00 UTC') },
        { tag_name: 'v1', published_at: Time.parse('2024-08-03 00:00:00 UTC') }
      ]
    end
    _, asked = refusing(:compare, octo)
    result = measure(octo, repos: %w[foo/a foo/b]) { some_release_hoc_size(fact) }
    assert_equal([['foo/a', 'v1', 'v2']], asked)
    assert_empty(result)
  end

  def test_review_time_stops_after_the_first_pull
    octo, asked = refusing(:pull_request_reviews)
    found = { items: [{ number: 10 }, { number: 11 }] }
    result = measure(octo, search: found) { some_review_time(fact) }
    assert_equal([['foo/foo', 10]], asked)
    assert_empty(result)
  end

  def test_triage_time_stops_after_the_first_repository
    octo, asked = refusing(:repo_id_by_name)
    seconds = Struct.new(:value).new(60)
    quality = Struct.new(:qos_min_triage_seconds).new(seconds)
    pmp = Struct.new(:quality).new(quality)
    found = { items: [{ number: 1, created_at: Time.parse('2024-08-03 00:00:00 UTC') }] }
    result =
      Fbe.stub(:pmp, pmp) do
        measure(octo, repos: %w[foo/a foo/b], search: found) { some_triage_time(fact) }
      end
    assert_equal([['foo/a']], asked)
    assert_empty(result)
  end

  def test_build_success_stops_while_listing_workflow_runs
    octo, asked = refusing(:repository_workflow_runs)
    result = measure(octo, repos: %w[foo/a foo/b]) { some_build_success_rate(fact) }
    assert_equal([['foo/a']], asked)
    assert_empty(result)
  end

  def test_build_success_stops_while_reading_run_usage
    octo = client
    started = Time.parse('2024-08-07 10:00:00 UTC')
    octo.define_singleton_method(:repository_workflow_runs) do |*|
      {
        workflow_runs: [1, 2].map do |id|
          {
            id:, status: 'completed', conclusion: 'success', workflow_id: 7,
            run_started_at: started
          }
        end
      }
    end
    _, asked = refusing(:workflow_run_usage, octo)
    result = measure(octo) { some_build_success_rate(fact) }
    assert_equal([['foo/foo', 1]], asked)
    assert_empty(result)
  end

  def test_build_success_stops_when_recovery_is_rate_limited
    octo = client
    started = Time.parse('2024-08-07 10:00:00 UTC')
    octo.define_singleton_method(:repository_workflow_runs) do |*|
      {
        workflow_runs: [10, 11].map do |workflow|
          {
            id: workflow, status: 'completed', conclusion: 'failure', workflow_id: workflow,
            run_started_at: started
          }
        end
      }
    end
    octo.define_singleton_method(:workflow_run_usage) { |*| { run_duration_ms: 1_000 } }
    octo.define_singleton_method(:with_disable_auto_paginate) { |&block| block.call(self) }
    _, asked = refusing(:workflow_runs, octo)
    result = measure(octo) { some_build_success_rate(fact) }
    assert_equal([['foo/foo', 10]], asked)
    assert_empty(result)
  end

  def test_recovered_names_the_rate_limit_instead_of_forbidden
    octo, = refusing(:workflow_runs)
    octo.define_singleton_method(:with_disable_auto_paginate) { |&block| block.call(self) }
    logs = []
    loog = Object.new
    loog.define_singleton_method(:warn) { |message| logs << message }
    Fbe.stub(:octo, octo) do
      assert_raises(Octokit::TooManyRequests) do
        Jp.recovered('foo/foo', 42, Time.parse('2024-08-09 21:00:00 UTC'), judge: 'quality-of-service', loog:)
      end
    end
    assert_match(/API rate limit exhausted/, logs.join)
    refute_match(/Access forbidden/, logs.join)
  end

  private

  def fact
    Struct.new(:since, :when).new(Time.parse('2024-08-02 21:00:00 UTC'), Time.parse('2024-08-09 21:00:00 UTC'))
  end

  def client
    octo = Object.new
    octo.define_singleton_method(:off_quota?) { |**| false }
    octo
  end

  def rate_limit
    Octokit::TooManyRequests.new(
      method: :get, url: 'https://api.github.com/x', status: 403,
      body: '{"message":"API rate limit exceeded"}'
    )
  end

  def refusing(name, octo = client)
    limit = rate_limit
    asked = []
    octo.define_singleton_method(name) do |*args, **|
      asked << args
      raise(limit)
    end
    [octo, asked]
  end

  def measure(octo, repos: ['foo/foo'], search: nil, &)
    Fbe.stub(:octo, octo) do
      Fbe.stub(:unmask_repos, ->(&yielded) { repos.each { |repo| yielded.call(repo) } }) do
        next yield if search.nil?
        Jp.stub(:qosearch, search, &)
      end
    end
  end
end
