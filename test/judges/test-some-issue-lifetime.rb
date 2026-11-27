# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'fbe/octo'
require 'fbe/unmask_repos'
require 'judges/options'
require 'loog'
require 'tmpdir'
require_relative '../../judges/quality-of-service/some_issue_lifetime'
require_relative '../../lib/incremate'
require_relative '../test__helper'

class TestSomeIssueLifetime < Jp::Test
  def test_keeps_the_issues_when_the_pull_search_fails
    fact = Factbase.new.insert
    fact.since = Time.parse('2025-01-01 00:00:00 UTC')
    fact.when = Time.parse('2025-02-01 00:00:00 UTC')
    $judge = 'quality-of-service'
    $loog = Loog::NULL
    $global = {}
    $options = Judges::Options.new({ 'repositories' => 'foo/foo' })
    octo = Object.new
    octo.define_singleton_method(:off_quota?) { |**| false }
    answers = [{ items: [{ closed_at: fact.since + 3600, created_at: fact.since }] }, nil]
    result =
      Fbe.stub(:octo, octo) do
        Fbe.stub(:unmask_repos, proc { |&b| b.call('foo/foo') }) do
          Jp.stub(:qosearch, proc { |*| answers.shift }) { some_issue_lifetime(fact) }
        end
      end
    assert_equal([3600.0], result['some_issue_lifetime'])
    refute_includes(result, 'some_pull_lifetime')
  end

  def test_runs_again_after_a_failed_pull_search
    issue = ages(3600)
    pull = ages(7200)
    pulls = 0
    queries = 0
    with_lifetime(
      proc do |query, **|
        queries += 1
        next issue unless query.include?('type:pr')
        pulls += 1
        pulls == 1 ? nil : pull
      end
    ) do |f, dir|
      Jp.incremate(f, dir, 'some', epoch: @time, kickoff: @time)
      assert_equal([3600.0], f['some_issue_lifetime'])
      assert_nil(f['some_pull_lifetime'])
      assert_nil(f['some_issue_lifetime_done'])
      assert_equal(%w[since some_issue_lifetime what when], f.all_properties.sort)
      Jp.incremate(f, dir, 'some', epoch: @time, kickoff: @time)
      assert_equal([3600.0], f['some_issue_lifetime'])
      assert_equal([7200.0], f['some_pull_lifetime'])
      assert_equal([1], f['some_issue_lifetime_done'])
      assert_equal(1, f['some_issue_lifetime'].size)
      assert_equal(4, queries)
      Jp.incremate(f, dir, 'some', epoch: @time, kickoff: @time)
      assert_equal(4, queries)
    end
  end

  def test_runs_again_after_a_failed_issue_search
    issue = ages(3600)
    pull = ages(7200)
    issues = 0
    with_lifetime(
      proc do |query, **|
        next pull unless query.include?('type:issue')
        issues += 1
        issues == 1 ? nil : issue
      end
    ) do |f, dir|
      Jp.incremate(f, dir, 'some', epoch: @time, kickoff: @time)
      assert_nil(f['some_issue_lifetime'])
      assert_equal([7200.0], f['some_pull_lifetime'])
      assert_nil(f['some_issue_lifetime_done'])
      assert_equal(%w[since some_pull_lifetime what when], f.all_properties.sort)
      Jp.incremate(f, dir, 'some', epoch: @time, kickoff: @time)
      assert_equal([3600.0], f['some_issue_lifetime'])
      assert_equal([7200.0], f['some_pull_lifetime'])
      assert_equal(1, f['some_pull_lifetime'].size)
      assert_equal([1], f['some_issue_lifetime_done'])
    end
  end

  def test_stops_when_the_pull_search_succeeds_with_nothing
    queries = 0
    with_lifetime(
      proc do |query, **|
        queries += 1
        query.include?('type:pr') ? { items: [] } : ages(3600)
      end
    ) do |f, dir|
      Jp.incremate(f, dir, 'some', epoch: @time, kickoff: @time)
      assert_equal([3600.0], f['some_issue_lifetime'])
      assert_nil(f['some_pull_lifetime'])
      assert_equal([1], f['some_issue_lifetime_done'])
      assert_equal(2, queries)
      Jp.incremate(f, dir, 'some', epoch: @time, kickoff: @time)
      assert_equal(2, queries)
    end
  end

  private

  def ages(seconds)
    opened = Time.parse('2024-01-01 00:00:00 UTC')
    { items: [{ closed_at: opened + seconds, created_at: opened }] }
  end

  def with_lifetime(search)
    prepare
    Dir.mktmpdir do |dir|
      source = File.expand_path('../../judges/quality-of-service/some_issue_lifetime.rb', __dir__)
      File.write(File.expand_path('some_issue_lifetime.rb', dir), "require #{source.inspect}\n")
      fact = Factbase.new.insert
      fact.what = 'quality-of-service'
      fact.since = Time.parse('2024-01-01Z')
      fact.when = Time.parse('2024-01-08Z')
      octo = Object.new
      octo.define_singleton_method(:off_quota?) { |**| false }
      Fbe.stub(:octo, octo) do
        Fbe.stub(:unmask_repos, proc { |*, **, &blk| blk.call('foo/foo') }) do
          Jp.stub(:qosearch, search) do
            yield(fact, dir)
          end
        end
      end
    end
  ensure
    $global = nil
    $local = nil
    $loog = nil
    $judge = nil
    $options = nil
    $epoch = nil
    $kickoff = nil
  end

  def prepare
    WebMock.disable_net_connect!
    $global = {}
    $local = {}
    $loog = Loog::NULL
    $judge = 'quality-of-service'
    $options = Judges::Options.new({ 'lifetime' => 100, 'timeout' => 100, 'repositories' => 'foo/foo' })
    @time = Time.now - 60
    $epoch = @time
    $kickoff = @time
  end
end
