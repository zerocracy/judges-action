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
    %i[repository_workflow_runs workflow_run_usage].each do |call|
      retry_metric(:some_build_success_rate, call, some_build_success_rate: [1, 1], some_build_duration: [1.0, 1.0])
    end
  end

  def test_retries_triage
    retry_metric(:some_triage_time, :repo_id_by_name, some_triage_time: [300.0, 300.0])
  end

  private

  def retry_metric(metric, failed, expected)
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
    octo = client(start, failed, failure)
    found = { items: [{ number: 1, created_at: start, pull_request: { merged_at: start + 3600 } }] }
    Fbe.stub(:octo, octo) do
      Fbe.stub(:fb, fb) do
        Fbe.stub(:over?, false) do
          Fbe.stub(:unmask_repos, ->(&block) { %w[foo/a foo/b].each(&block) }) do
            Jp.stub(:qosearch, found) do
              measure(metric, fact, failure, expected)
            end
          end
        end
      end
    end
  ensure
    $loog, $options, $global = previous
  end

  def measure(metric, fact, failure, expected)
    Dir.mktmpdir do |dir|
      source = File.expand_path("../../judges/quality-of-service/#{metric}.rb", __dir__)
      File.write(File.join(dir, "#{metric}.rb"), "require #{source.inspect}\n")
      File.write(File.join(dir, 'some_zzz_probe.rb'), "def some_zzz_probe(_fact) = { some_zzz_probe: 13 }\n")
      Jp.incremate(fact, dir, 'some')
      expected.each_key { |key| assert_nil(fact[key.to_s], "#{key} was frozen after a forbidden lookup") }
      assert_nil(fact[Jp::INCREMATE_MARKER], 'an incomplete metric was marked complete')
      assert_equal(13, fact.some_zzz_probe, 'the other metrics must still be evaluated')
      failure[:active] = false
      Jp.incremate(fact, dir, 'some')
      expected.each { |key, values| assert_equal(values, fact[key.to_s], "#{key} did not recover both repositories") }
    end
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

  def client(start, failed, failure)
    responses = {
      releases: [{ tag_name: 'b', published_at: start + 3600 }, { tag_name: 'a', published_at: start }],
      compare: { files: [{ changes: 5 }], total_commits: 2 },
      pull_request: { additions: 2, deletions: 3, changed_files: 1 },
      pull_request_reviews: [{ submitted_at: start + 600, user: { id: 1 } }],
      review_comments: [{}],
      repository_workflow_runs: {
        workflow_runs: [{ id: 1, workflow_id: 1, status: 'completed', conclusion: 'success', run_started_at: start }]
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
          raise(Octokit::Forbidden) if failure[:active] && name == failed && repo == 'foo/b'
          value.respond_to?(:call) ? value.call(repo) : value
        end
      end
    end
  end
end
