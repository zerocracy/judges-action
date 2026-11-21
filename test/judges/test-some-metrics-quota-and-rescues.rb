# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'fbe/fb'
require 'fbe/octo'
require 'fbe/pmp'
require 'judges/options'
require 'loog'
require_relative '../test__helper'

class TestSomeMetricsQuotaAndRescues < Jp::Test
  def test_some_pull_hoc_size_stops_on_quota
    octo = fake_octo(quota: true)
    octo.define_singleton_method(:pull_request) { |*| raise(RuntimeError, 'the quota check did not stop us') }
    result =
      Jp.stub(:qosearch, proc { |*| raise(RuntimeError, 'the quota check did not stop us') }) do
        run_metric('some_pull_hoc_size', %w[foo/foo], octo, proc { some_pull_hoc_size(fact) })
      end
    assert_empty(result)
  end

  def test_some_pull_hoc_size_skips_not_found_pull
    octo = fake_octo
    octo.define_singleton_method(:pull_request) do |_repo, number|
      raise(Octokit::NotFound) if number == 10
      { additions: 2, deletions: 3, changed_files: 1 }
    end
    result =
      Jp.stub(:qosearch, proc { |*| { items: [{ number: 10 }, { number: 11 }] } }) do
        run_metric('some_pull_hoc_size', %w[foo/foo], octo, proc { some_pull_hoc_size(fact) })
      end
    assert_equal({ some_pull_hoc_size: [5], some_pull_files_size: [1] }, result)
  end

  def test_some_pull_hoc_size_skips_forbidden_pull
    octo = fake_octo
    octo.define_singleton_method(:pull_request) do |_repo, number|
      raise(Octokit::Forbidden) if number == 10
      { additions: 2, deletions: 3, changed_files: 1 }
    end
    result =
      Jp.stub(:qosearch, proc { |*| { items: [{ number: 10 }, { number: 11 }] } }) do
        run_metric('some_pull_hoc_size', %w[foo/foo], octo, proc { some_pull_hoc_size(fact) })
      end
    assert_equal({ some_pull_hoc_size: [5], some_pull_files_size: [1] }, result)
  end

  def test_some_release_hoc_size_stops_on_quota
    octo = fake_octo(quota: true)
    octo.define_singleton_method(:releases) { |*| raise(RuntimeError, 'the quota check did not stop us') }
    result = run_metric('some_release_hoc_size', %w[foo/foo], octo, proc { some_release_hoc_size(fact) })
    assert_empty(result)
  end

  def test_some_release_hoc_size_skips_not_found_releases
    assert_release_hoc_size_skips_releases(Octokit::NotFound)
  end

  def test_some_release_hoc_size_skips_forbidden_releases
    assert_release_hoc_size_skips_releases(Octokit::Forbidden)
  end

  def test_some_release_hoc_size_skips_not_found_compare
    assert_release_hoc_size_skips_compare(Octokit::NotFound)
  end

  def test_some_release_hoc_size_skips_forbidden_compare
    assert_release_hoc_size_skips_compare(Octokit::Forbidden)
  end

  def test_some_release_interval_stops_on_quota
    octo = fake_octo(quota: true)
    octo.define_singleton_method(:releases) { |*| raise(RuntimeError, 'the quota check did not stop us') }
    result = run_metric('some_release_interval', %w[foo/foo], octo, proc { some_release_interval(fact) })
    assert_empty(result)
  end

  def test_some_release_interval_skips_not_found_releases
    assert_release_interval_skips_releases(Octokit::NotFound)
  end

  def test_some_release_interval_skips_forbidden_releases
    assert_release_interval_skips_releases(Octokit::Forbidden)
  end

  def test_some_review_time_stops_on_quota
    octo = fake_octo(quota: true)
    result =
      Jp.stub(:qosearch, proc { |*| raise(RuntimeError, 'the quota check did not stop us') }) do
        run_metric('some_review_time', %w[foo/foo], octo, proc { some_review_time(fact) })
      end
    assert_empty(result)
  end

  def test_some_review_time_skips_forbidden_pull
    merged = Time.parse('2024-08-09 00:00:00 UTC')
    octo = fake_octo
    octo.define_singleton_method(:pull_request_reviews) do |_repo, number|
      raise(Octokit::Forbidden) if number == 12
      [{ submitted_at: Time.parse('2024-08-08 00:00:00 UTC'), user: { id: 1 } }]
    end
    octo.define_singleton_method(:review_comments) do |_repo, number|
      raise(Octokit::Forbidden) if number == 12
      [{}]
    end
    result =
      Jp.stub(
        :qosearch,
        proc do |*|
          {
            items: [
              { number: 12, pull_request: { merged_at: merged } },
              { number: 14, pull_request: { merged_at: merged } }
            ]
          }
        end
      ) do
        run_metric('some_review_time', %w[foo/foo], octo, proc { some_review_time(fact) })
      end
    assert_equal(
      {
        some_review_time: [86_400],
        some_review_size: [1],
        some_reviewers_per_pull: [1],
        some_reviews_per_pull: [1]
      },
      result
    )
  end

  def test_some_triage_time_stops_on_quota
    octo = fake_octo(quota: true)
    result =
      Jp.stub(:qosearch, proc { |*| raise(RuntimeError, 'the quota check did not stop us') }) do
        Fbe.stub(:pmp, fake_pmp) do
          run_metric('some_triage_time', %w[foo/foo], octo, proc { some_triage_time(fact) })
        end
      end
    assert_empty(result)
  end

  def test_some_triage_time_skips_not_found_repository
    assert_triage_time_skips_repository(Octokit::NotFound)
  end

  def test_some_triage_time_skips_forbidden_repository
    assert_triage_time_skips_repository(Octokit::Forbidden)
  end

  private

  def assert_release_hoc_size_skips_releases(error)
    first = { tag_name: 'v1', published_at: Time.parse('2024-08-03 00:00:00 UTC') }
    second = { tag_name: 'v2', published_at: Time.parse('2024-08-05 00:00:00 UTC') }
    octo = fake_octo
    octo.define_singleton_method(:releases) do |repo|
      raise(error) if repo == 'foo/bad'
      [first, second]
    end
    octo.define_singleton_method(:compare) do |*|
      { files: [{ changes: 2 }, { changes: 3 }], total_commits: 4 }
    end
    result = run_metric('some_release_hoc_size', %w[foo/bad foo/good], octo, proc { some_release_hoc_size(fact) })
    assert_equal({ some_release_hoc_size: [5], some_release_commits_size: [4] }, result)
  end

  def assert_release_hoc_size_skips_compare(error)
    first = { tag_name: 'v1', published_at: Time.parse('2024-08-03 00:00:00 UTC') }
    second = { tag_name: 'v2', published_at: Time.parse('2024-08-05 00:00:00 UTC') }
    octo = fake_octo
    octo.define_singleton_method(:releases) { |*| [first, second] }
    octo.define_singleton_method(:compare) do |repo, *|
      raise(error) if repo == 'foo/bad'
      { files: [{ changes: 2 }, { changes: 3 }], total_commits: 4 }
    end
    result = run_metric('some_release_hoc_size', %w[foo/bad foo/good], octo, proc { some_release_hoc_size(fact) })
    assert_equal({ some_release_hoc_size: [5], some_release_commits_size: [4] }, result)
  end

  def assert_release_interval_skips_releases(error)
    first = { published_at: Time.parse('2024-08-03 00:00:00 UTC') }
    second = { published_at: Time.parse('2024-08-05 00:00:00 UTC') }
    octo = fake_octo
    octo.define_singleton_method(:releases) do |repo|
      raise(error) if repo == 'foo/bad'
      [first, second]
    end
    result = run_metric('some_release_interval', %w[foo/bad foo/good], octo, proc { some_release_interval(fact) })
    assert_equal({ some_release_interval: [172_800] }, result)
  end

  def assert_triage_time_skips_repository(error)
    octo = fake_octo
    octo.define_singleton_method(:repo_id_by_name) do |repo|
      raise(error) if repo == 'foo/bad'
      42
    end
    fb = Factbase.new
    label = fb.insert
    label.what = 'label-was-attached'
    label.repository = 42
    label.issue = 1
    label.label = 'bug'
    label.when = Time.parse('2024-08-04 00:00:00 UTC')
    label.where = 'github'
    original = fb.method(:query)
    fb.define_singleton_method(:query) do |query|
      raise(RuntimeError, "a skipped repository reached the query: #{query}") if query.include?('(eq repository )')
      original.call(query)
    end
    result =
      Jp.stub(
        :qosearch,
        proc do |*|
          { items: [{ number: 1, created_at: Time.parse('2024-08-03 00:00:00 UTC') }] }
        end
      ) do
        Fbe.stub(:pmp, fake_pmp) do
          Fbe.stub(:fb, fb) do
            run_metric('some_triage_time', %w[foo/bad foo/good], octo, proc { some_triage_time(fact) })
          end
        end
      end
    assert_equal({ some_triage_time: [86_400] }, result)
  end

  def run_metric(metric, repos, octo, action)
    $judge = 'quality-of-service'
    $loog = Loog::NULL
    $global = {}
    $options = Judges::Options.new({ 'repositories' => repos.join(',') })
    load(File.join(__dir__, "../../judges/quality-of-service/#{metric}.rb"))
    Fbe.stub(:octo, octo) do
      Fbe.stub(:unmask_repos, proc { |&b| repos.each(&b) }) { action.call }
    end
  end

  def fake_octo(quota: false)
    octo = Object.new
    octo.define_singleton_method(:off_quota?) { |**| quota }
    octo
  end

  def fake_pmp
    quality = Object.new
    quality.define_singleton_method(:qos_min_triage_seconds) { Struct.new(:value).new(60) }
    pmp = Object.new
    pmp.define_singleton_method(:quality) { quality }
    pmp
  end

  def fact
    Struct.new(:since, :when).new(Time.parse('2024-08-02T21:00:00Z'), Time.parse('2024-08-09T21:00:00Z'))
  end
end
