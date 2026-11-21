# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'judges/options'
require 'loog'
require_relative '../../judges/quality-of-service/some_build_success_rate'
require_relative '../../judges/quality-of-service/some_pull_hoc_size'
require_relative '../../judges/quality-of-service/some_release_hoc_size'
require_relative '../../judges/quality-of-service/some_release_interval'
require_relative '../../judges/quality-of-service/some_review_time'
require_relative '../../judges/quality-of-service/some_triage_time'
require_relative '../fake_github'
require_relative '../test__helper'

class TestSomeTransient < Jp::Test
  def test_keeps_the_other_repository_when_releases_are_unavailable
    rackenv = ENV.fetch('RACK_ENV', nil)
    ENV['RACK_ENV'] = 'test'
    seed = Random.new_seed
    gap = Random.new(seed).rand(600..86_400)
    base = Time.parse('2024-08-10 00:00:00 UTC')
    good = [{ id: 2, published_at: (base + gap).utc.iso8601 }, { id: 1, published_at: base.utc.iso8601 }]
    fact = Factbase.new.insert
    fact.since = Time.parse('2024-08-01 00:00:00 UTC')
    fact.when = Time.parse('2024-09-01 00:00:00 UTC')
    $judge = 'quality-of-service'
    $global = {}
    log = Loog::Buffer.new
    $loog = log
    $options = Judges::Options.new({ 'repositories' => 'foo/bad,foo/good' })
    intervals =
      Jp::FakeGithub.new(
        'GET /rate_limit' => {
          resources: {
            core: { remaining: 5000, limit: 5000 },
            search: { remaining: 30, limit: 30 }
          },
          rate: { remaining: 5000, limit: 5000 }
        },
        'GET /repos/foo/bad' => { id: 41, full_name: 'foo/bad', archived: false },
        'GET /repos/foo/good' => { id: 42, full_name: 'foo/good', archived: false },
        'GET /repos/foo/bad/releases?per_page=100' => [502, { message: 'Bad Gateway' }],
        'GET /repos/foo/good/releases?per_page=100' => [200, good]
      ).run { some_release_interval(fact)[:some_release_interval] }
    assert_equal([gap], intervals, "a 502 on foo/bad dropped foo/good, seed #{seed}")
    assert_includes(log.to_s, 'Transient error fetching releases for foo/bad')
  ensure
    rackenv.nil? ? ENV.delete('RACK_ENV') : ENV['RACK_ENV'] = rackenv
  end

  def test_keeps_the_other_repository_when_workflow_runs_answer_bad_gateway
    started = Time.parse('2024-08-07 10:00:00 UTC')
    octo = quiet_octo
    octo.define_singleton_method(:repository_workflow_runs) do |repo, **|
      raise(Octokit::BadGateway) if repo == 'foo/bad'
      {
        workflow_runs: [
          {
            id: 2, status: 'completed', conclusion: 'success', workflow_id: 101,
            run_started_at: started
          }
        ]
      }
    end
    octo.define_singleton_method(:workflow_run_usage) { |*, **| { run_duration_ms: 900_000 } }
    metrics = call_repos(octo) { some_build_success_rate(window) }
    assert_equal([1], metrics[:some_build_success_rate])
    assert_equal([900], metrics[:some_build_duration])
  end

  def test_keeps_the_other_repository_when_workflow_runs_time_out
    started = Time.parse('2024-08-07 10:00:00 UTC')
    octo = quiet_octo
    octo.define_singleton_method(:repository_workflow_runs) do |repo, **|
      raise(Faraday::TimeoutError, 'execution expired') if repo == 'foo/bad'
      {
        workflow_runs: [
          {
            id: 2, status: 'completed', conclusion: 'success', workflow_id: 101,
            run_started_at: started
          }
        ]
      }
    end
    octo.define_singleton_method(:workflow_run_usage) { |*, **| { run_duration_ms: 900_000 } }
    metrics = call_repos(octo) { some_build_success_rate(window) }
    assert_equal([900], metrics[:some_build_duration])
  end

  def test_keeps_the_other_run_when_workflow_usage_answers_bad_gateway
    started = Time.parse('2024-08-07 10:00:00 UTC')
    octo = quiet_octo
    octo.define_singleton_method(:repository_workflow_runs) do |*|
      {
        workflow_runs: [
          {
            id: 1, status: 'completed', conclusion: 'success', workflow_id: 101,
            run_started_at: started
          },
          {
            id: 2, status: 'completed', conclusion: 'success', workflow_id: 101,
            run_started_at: started + 3600
          }
        ]
      }
    end
    octo.define_singleton_method(:workflow_run_usage) do |_, id|
      raise(Octokit::BadGateway) if id == 1
      { run_duration_ms: 600_000 }
    end
    metrics = call_repos(octo, repos: ['foo/foo']) { some_build_success_rate(window) }
    assert_equal([600], metrics[:some_build_duration])
  end

  def test_keeps_the_other_repository_when_release_list_answers_bad_gateway
    octo = quiet_octo
    octo.define_singleton_method(:releases) do |repo|
      raise(Octokit::BadGateway) if repo == 'foo/bad'
      [
        { tag_name: 'v2', published_at: Time.parse('2024-08-20 00:00:00 UTC') },
        { tag_name: 'v1', published_at: Time.parse('2024-08-10 00:00:00 UTC') },
        { tag_name: 'v0', published_at: Time.parse('2024-07-01 00:00:00 UTC') }
      ]
    end
    octo.define_singleton_method(:compare) do |*|
      { files: [{ changes: 4 }, { changes: 6 }], total_commits: 3 }
    end
    metrics = call_repos(octo) { some_release_hoc_size(window) }
    assert_equal([10, 10], metrics[:some_release_hoc_size])
    assert_equal([3, 3], metrics[:some_release_commits_size])
  end

  def test_keeps_the_other_pair_when_compare_answers_bad_gateway
    octo = quiet_octo
    calls = 0
    octo.define_singleton_method(:releases) do |*|
      [
        { tag_name: 'v2', published_at: Time.parse('2024-08-20 00:00:00 UTC') },
        { tag_name: 'v1', published_at: Time.parse('2024-08-10 00:00:00 UTC') },
        { tag_name: 'v0', published_at: Time.parse('2024-07-01 00:00:00 UTC') }
      ]
    end
    octo.define_singleton_method(:compare) do |*|
      calls += 1
      raise(Octokit::BadGateway) if calls == 1
      { files: [{ changes: 7 }], total_commits: 2 }
    end
    metrics = call_repos(octo, repos: ['foo/foo']) { some_release_hoc_size(window) }
    assert_equal([7], metrics[:some_release_hoc_size])
    assert_equal([2], metrics[:some_release_commits_size])
  end

  def test_keeps_the_other_pull_when_pull_request_answers_bad_gateway
    found = { items: [{ number: 8 }, { number: 9 }] }
    octo = quiet_octo
    octo.define_singleton_method(:pull_request) do |_, number|
      raise(Octokit::BadGateway) if number == 8
      { additions: 3, deletions: 4, changed_files: 2 }
    end
    metrics =
      call_repos(octo, repos: ['foo/foo']) do
        Jp.stub(:qosearch, found) { some_pull_hoc_size(window) }
      end
    assert_equal([7], metrics[:some_pull_hoc_size])
    assert_equal([2], metrics[:some_pull_files_size])
  end

  def test_keeps_the_other_pull_when_the_connection_fails
    found = { items: [{ number: 8 }, { number: 9 }] }
    octo = quiet_octo
    octo.define_singleton_method(:pull_request) do |_, number|
      raise(Faraday::ConnectionFailed, 'connection refused') if number == 8
      { additions: 1, deletions: 1, changed_files: 1 }
    end
    metrics =
      call_repos(octo, repos: ['foo/foo']) do
        Jp.stub(:qosearch, found) { some_pull_hoc_size(window) }
      end
    assert_equal([2], metrics[:some_pull_hoc_size])
  end

  def test_keeps_the_other_pull_when_reviews_answer_bad_gateway
    merged = Time.parse('2024-08-20 12:00:00 UTC')
    submitted = Time.parse('2024-08-20 10:00:00 UTC')
    found = {
      items: [
        { number: 8, pull_request: { merged_at: merged } },
        { number: 9, pull_request: { merged_at: merged } }
      ]
    }
    octo = quiet_octo
    octo.define_singleton_method(:pull_request_reviews) do |_, number|
      raise(Octokit::BadGateway) if number == 8
      [{ user: { id: 9 }, submitted_at: submitted }]
    end
    octo.define_singleton_method(:review_comments) do |_, number|
      raise(Octokit::BadGateway) if number == 8
      [{ id: 1 }, { id: 2 }]
    end
    metrics =
      call_repos(octo, repos: ['foo/foo']) do
        Jp.stub(:qosearch, found) { some_review_time(window) }
      end
    assert_equal([7200], metrics[:some_review_time])
    assert_equal([2], metrics[:some_review_size])
    assert_equal([1], metrics[:some_reviewers_per_pull])
    assert_equal([1], metrics[:some_reviews_per_pull])
  end

  def test_keeps_the_other_repository_when_repo_lookup_answers_bad_gateway
    created = Time.parse('2024-08-04 12:00:00 UTC')
    found = { items: [{ number: 7, created_at: created }] }
    $fb = Factbase.new
    labeled = $fb.insert
    labeled.what = 'label-was-attached'
    labeled.repository = 43
    labeled.issue = 7
    labeled.label = 'bug'
    labeled.where = 'github'
    labeled.when = created + 7200
    octo = quiet_octo
    octo.define_singleton_method(:repo_id_by_name) do |repo|
      raise(Octokit::BadGateway) if repo == 'foo/bad'
      43
    end
    times =
      call_repos(octo) do
        Jp.stub(:qosearch, found) { some_triage_time(window)[:some_triage_time] }
      end
    assert_equal([7200], times)
  end

  private

  def window
    Struct.new(:since, :when).new(Time.parse('2024-08-01 00:00:00 UTC'), Time.parse('2024-09-01 00:00:00 UTC'))
  end

  def quiet_octo
    octo = Object.new
    octo.define_singleton_method(:off_quota?) { |**| false }
    octo
  end

  def call_repos(octo, repos: %w[foo/bad foo/good], &)
    $judge = 'quality-of-service'
    $loog = Loog::NULL
    $global = {}
    $options = Judges::Options.new({ 'repositories' => repos.join(',') })
    $fb ||= Factbase.new
    Fbe.stub(:octo, octo) do
      Fbe.stub(:unmask_repos, proc { |&b| repos.each { b.call(_1) } }, &)
    end
  end
end
