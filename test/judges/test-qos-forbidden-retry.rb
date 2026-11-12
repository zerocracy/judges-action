# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'tmpdir'
require_relative '../test__helper'

require_relative '../../judges/quality-of-service/some_build_success_rate'
require_relative '../../judges/quality-of-service/some_pull_hoc_size'
require_relative '../../judges/quality-of-service/some_release_hoc_size'
require_relative '../../judges/quality-of-service/some_release_interval'
require_relative '../../judges/quality-of-service/some_review_time'
require_relative '../../judges/quality-of-service/some_triage_time'
require_relative '../../lib/incremate'

class TestQosForbiddenRetry < Jp::Test
  def test_retries_release_intervals
    retry_metric(:some_release_interval, :releases, some_release_interval: [3600.0, 3600.0])
  end

  def test_retries_release_sizes
    %i[releases compare].each do |call|
      retry_metric(:some_release_hoc_size, call, some_release_hoc_size: [5, 5], some_release_commits_size: [2, 2])
    end
  end

  def test_retries_pull_sizes
    retry_metric(:some_pull_hoc_size, :pull_request, some_pull_hoc_size: [5, 5], some_pull_files_size: [1, 1])
  end

  def test_retries_reviews
    expected = {
      some_review_time: [3000, 3000], some_review_size: [1, 1],
      some_reviewers_per_pull: [1, 1], some_reviews_per_pull: [1, 1]
    }
    %i[pull_request_reviews review_comments].each do |call|
      retry_metric(:some_review_time, call, expected)
    end
  end

  def test_retries_builds
    expected = {
      some_build_success_rate: [0, 1, 0, 1], some_build_duration: [1.0, 1.0, 1.0, 1.0],
      some_build_mttr: [120, 120]
    }
    %i[repository_workflow_runs workflow_run_usage].each do |call|
      retry_metric(:some_build_success_rate, call, expected)
    end
  end

  def test_retries_triage
    retry_metric(:some_triage_time, :repo_id_by_name, some_triage_time: [300.0, 300.0])
  end

  def test_does_not_swallow_other_http_client_errors
    [400, 429].each do |status|
      error = Octokit::Error.from_response(status:, body: 'Client error', response_headers: {})
      raised =
        assert_raises(error.class) do
          exercise_metric(:some_release_interval, :releases, { some_release_interval: [3600.0, 3600.0] }, error)
        end
      assert_same(error, raised)
    end
  end

  private

  def retry_metric(metric, failed, expected)
    ['API rate limit exceeded', 'You have triggered an abuse detection mechanism'].each do |message|
      error = Octokit::Error.from_response(status: 403, body: message, response_headers: {})
      exercise_metric(metric, failed, expected, error)
    end
    [false, true].each do |reverse|
      error = denied_error
      exercise_metric(metric, failed, expected, error, permanent: true, reverse:)
    end
    error = denied_error
    exercise_metric(metric, failed, expected, error, permanent: true, only_denied: true)
  end

  def denied_error
    Octokit::Error.from_response(status: 403, body: 'Resource not accessible by integration', response_headers: {})
  end

  def exercise_metric(metric, failed, expected, error, permanent: false, reverse: false, only_denied: false)
    WebMock.disable_net_connect!
    previous = [$loog, $options, $global]
    $loog = Loog::NULL
    $options = Judges::Options.new
    $global = {}
    start = Time.utc(2025, 1, 1)
    fb = factbase(start)
    fact = fb.insert
    fact.since = start - 1
    fact.when = start + 7200
    failure = { active: true }
    octo = client(start, failed, failure, error)
    found = { items: [{ number: 1, created_at: start, pull_request: { merged_at: start + 3600 } }] }
    repos = %w[foo/a foo/b]
    repos.reverse! if reverse
    repos = ['foo/b'] if only_denied
    Fbe.stub(:octo, octo) do
      Fbe.stub(:fb, fb) do
        Fbe.stub(:over?, false) do
          Fbe.stub(:unmask_repos, ->(&block) { repos.each(&block) }) do
            Jp.stub(:qosearch, found) do
              measure(metric, fact, failure, expected, permanent:, only_denied:)
            end
          end
        end
      end
    end
  ensure
    $loog, $options, $global = previous
  end

  def measure(metric, fact, failure, expected, permanent:, only_denied:)
    Dir.mktmpdir do |dir|
      source = File.expand_path("../../judges/quality-of-service/#{metric}.rb", __dir__)
      File.write(File.join(dir, "#{metric}.rb"), "require #{source.inspect}\n")
      File.write(File.join(dir, 'some_zzz_probe.rb'), "def some_zzz_probe(_fact) = { some_zzz_probe: 13 }\n")
      Jp.incremate(fact, dir, 'some')
      if permanent
        expected.each do |key, values|
          if only_denied
            assert_nil(fact[key.to_s], "#{key} must keep the accessible repository")
          else
            assert_equal(values.take(values.length / 2), fact[key.to_s], "#{key} must keep the accessible repository")
          end
        end
        assert_includes(fact[Jp::INCREMATE_MARKER], metric.to_s) if only_denied
        Jp.incremate(fact, dir, 'some')
        expected.each do |key, values|
          if only_denied
            assert_nil(fact[key.to_s], "#{key} must not duplicate accessible data")
          else
            assert_equal(values.take(values.length / 2), fact[key.to_s], "#{key} must not duplicate accessible data")
          end
        end
        next
      end
      expected.each_key { |key| assert_nil(fact[key.to_s], "#{key} was frozen after a forbidden lookup") }
      assert_nil(fact[Jp::INCREMATE_MARKER], 'an incomplete metric was marked complete')
      assert_equal(13, fact.some_zzz_probe, 'the other metrics must still be evaluated')
      failure[:active] = false
      Jp.incremate(fact, dir, 'some')
      expected.each do |key, values|
        assert_equal(values, fact[key.to_s], "#{key} did not recover both repositories")
      end
    end
  rescue Octokit::ClientError
    expected.each_key { |key| assert_nil(fact[key.to_s], "#{key} must not retain a subtotal after an HTTP error") }
    assert_nil(fact[Jp::INCREMATE_MARKER], 'an HTTP error must not mark an incomplete metric complete')
    raise
  end

  def factbase(start)
    fb = Factbase.new
    [42, 43].each do |repo|
      fact = fb.insert
      fact.what = 'label-was-attached'
      fact.repository = repo
      fact.issue = 1
      fact.label = 'bug'
      fact.where = 'github'
      fact.when = start + 300
    end
    fb
  end

  def client(start, failed, failure, error)
    responses = {
      releases: [{ tag_name: 'b', published_at: start + 3600 }, { tag_name: 'a', published_at: start }],
      compare: { files: [{ changes: 5 }], total_commits: 2 },
      pull_request: { additions: 2, deletions: 3, changed_files: 1 },
      pull_request_reviews: [{ submitted_at: start + 600, user: { id: 1 } }],
      review_comments: [{}],
      repository_workflow_runs: {
        workflow_runs: [
          { id: 1, workflow_id: 1, status: 'completed', conclusion: 'failure', run_started_at: start },
          { id: 2, workflow_id: 1, status: 'completed', conclusion: 'success', run_started_at: start + 120 }
        ]
      },
      workflow_run_usage: { run_duration_ms: 1000 },
      repo_id_by_name: lambda do |repo|
        repo == 'foo/a' ? 42 : 43
      end
    }
    Object.new.tap do |octo|
      octo.define_singleton_method(:off_quota?) { false }
      responses.each do |name, value|
        octo.define_singleton_method(name) do |repo, *|
          raise(error) if failure[:active] && name == failed && repo == 'foo/b'
          value.respond_to?(:call) ? value.call(repo) : value
        end
      end
    end
  end
end
