# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'fbe/github_graph'
require 'fbe/octo'
require 'json'
require 'judges/options'
require 'loog'
require_relative '../test__helper'

class TestDimensionsOfTerrain < Jp::Test
  def test_total_repositories
    fb = Factbase.new
    rate_limit_up
    Fbe.stub(:github_graph, Fbe::Graph::Fake.new) do
      Time.stub(:now, Time.parse('2024-09-29 21:00:00 UTC')) do
        VCR.use_cassette('dimensions-of-terrain/total-repositories') do
          load_it('dimensions-of-terrain', fb,
                  Judges::Options.new({ 'repositories' => 'foo/foo,foo/bar,foo/qwe,foo/asd' }))
        end
        f = fb.query("(eq what 'dimensions-of-terrain')").each.first
        assert_equal('dimensions-of-terrain', f.what)
        assert_equal(Time.parse('2024-09-29 21:00:00 UTC'), f.when)
        assert_equal(3, f.total_repositories)
      end
    end
  end

  def test_total_releases_skips_non_array_response
    rate_limit_up
    fb = Factbase.new
    Fbe.stub(:github_graph, Fbe::Graph::Fake.new) do
      Time.stub(:now, Time.parse('2024-09-29 21:00:00 UTC')) do
        VCR.use_cassette('dimensions-of-terrain/total-releases-skips-non-array-response') do
          load_it('dimensions-of-terrain', fb)
        end
        f = fb.query("(eq what 'dimensions-of-terrain')").each.first
        assert_equal(0, f.total_releases)
      end
    end
  end

  def test_total_contributors_skips_non_array_response
    rate_limit_up
    fb = Factbase.new
    Fbe.stub(:github_graph, Fbe::Graph::Fake.new) do
      Time.stub(:now, Time.parse('2024-09-29 21:00:00 UTC')) do
        VCR.use_cassette('dimensions-of-terrain/total-contributors-skips-non-array-response') do
          load_it('dimensions-of-terrain', fb)
        end
        f = fb.query("(eq what 'dimensions-of-terrain')").each.first
        assert_equal(0, f.total_contributors)
      end
    end
  end

  def test_total_releases
    fb = Factbase.new
    rate_limit_up
    Fbe.stub(:github_graph, Fbe::Graph::Fake.new) do
      Time.stub(:now, Time.parse('2024-09-29 21:00:00 UTC')) do
        VCR.use_cassette('dimensions-of-terrain/total-releases') do
          load_it('dimensions-of-terrain', fb)
        end
        f = fb.query("(eq what 'dimensions-of-terrain')").each.first
        assert_equal(Time.parse('2024-09-29 21:00:00 UTC'), f.when)
        assert_equal(9, f.total_releases)
      end
    end
  end

  def test_total_stars_and_forks
    fb = Factbase.new
    rate_limit_up
    Fbe.stub(:github_graph, Fbe::Graph::Fake.new) do
      Time.stub(:now, Time.parse('2024-09-29 21:00:00 UTC')) do
        VCR.use_cassette('dimensions-of-terrain/total-stars-and-forks') do
          load_it('dimensions-of-terrain', fb, Judges::Options.new({ 'repositories' => 'foo/foo,foo/bar' }))
        end
        f = fb.query("(eq what 'dimensions-of-terrain')").each.first
        assert_equal(Time.parse('2024-09-29 21:00:00 UTC'), f.when)
        assert_equal(20, f.total_stars)
        assert_equal(15, f.total_forks)
      end
    end
  end

  def test_total_issues_and_pull_requests
    fb = Factbase.new
    VCR.use_cassette('dimensions-of-terrain/total-issues-and-pull-requests') do
      load_it('dimensions-of-terrain', fb, Judges::Options.new({ 'repositories' => 'foo/foo', 'testing' => true }))
    end
    f = fb.query("(eq what 'dimensions-of-terrain')").each.first
    assert_equal(23, f.total_issues)
    assert_equal(19, f.total_pulls)
  end

  def test_total_issues_skips_failing_graph_repo
    rate_limit_up
    $judge = 'dimensions-of-terrain'
    $global = {}
    $local = {}
    $loog = Loog::NULL
    $options = Judges::Options.new({ 'repositories' => 'foo/bad,foo/good' })
    graph = Class.new(Fbe::Graph::Fake) do
      define_method(:total_issues_and_pulls) do |_owner, name|
        raise(GraphQL::Client::Error, 'GraphQL failed') if name == 'bad'
        { 'issues' => 7, 'pulls' => 5 }
      end
    end.new
    Fbe.stub(:github_graph, graph) do
      VCR.use_cassette('dimensions-of-terrain/total-issues-skips-failing-graph-repo') do
        load(File.join(__dir__, '../../judges/dimensions-of-terrain/total_issues.rb'))
        assert_equal({ total_issues: 7, total_pulls: 5 }, total_issues(nil))
      end
    end
  end

  def test_total_issues_does_not_swallow_local_graph_bug
    rate_limit_up
    $judge = 'dimensions-of-terrain'
    $global = {}
    $local = {}
    $loog = Loog::NULL
    $options = Judges::Options.new({ 'repositories' => 'foo/bad' })
    graph = Class.new(Fbe::Graph::Fake) do
      define_method(:total_issues_and_pulls) do |_owner, _name|
        raise(NoMethodError, 'local bug')
      end
    end.new
    Fbe.stub(:github_graph, graph) do
      VCR.use_cassette('dimensions-of-terrain/total-issues-does-not-swallow-local-graph-bug') do
        load(File.join(__dir__, '../../judges/dimensions-of-terrain/total_issues.rb'))
        assert_raises(NoMethodError) { total_issues(nil) }
      end
    end
  end

  def test_total_commits
    fb = Factbase.new
    VCR.use_cassette('dimensions-of-terrain/total-commits') do
      load_it('dimensions-of-terrain', fb,
              Judges::Options.new({ 'repositories' => 'foo/foo,yegor256/empty-repo', 'testing' => true }))
    end
    f = fb.query("(eq what 'dimensions-of-terrain')").each.first
    assert_equal(1484, f.total_commits)
  end

  def test_total_commits_with_nil_size_repo
    fb = Factbase.new
    rate_limit_up
    Fbe.stub(:github_graph, Fbe::Graph::Fake.new) do
      Time.stub(:now, Time.parse('2024-09-29 21:00:00 UTC')) do
        VCR.use_cassette('dimensions-of-terrain/total-commits-with-nil-size-repo') do
          load_it('dimensions-of-terrain', fb, Judges::Options.new({ 'repositories' => 'foo/foo,foo/nil-size' }))
        end
        f = fb.query("(eq what 'dimensions-of-terrain')").each.first
        assert_equal(Time.parse('2024-09-29 21:00:00 UTC'), f.when)
        assert_equal(2, f.total_repositories)
        assert_equal(1484, f.total_commits)
        assert_equal(0, f.total_files)
        assert_equal(0, f.total_contributors)
      end
    end
  end

  def test_total_files
    fb = Factbase.new
    rate_limit_up
    Fbe.stub(:github_graph, Fbe::Graph::Fake.new) do
      Time.stub(:now, Time.parse('2024-09-29 21:00:00 UTC')) do
        VCR.use_cassette('dimensions-of-terrain/total-files') do
          load_it('dimensions-of-terrain', fb, Judges::Options.new({ 'repositories' => 'foo/foo,yegor256/empty-repo' }))
        end
        f = fb.query("(eq what 'dimensions-of-terrain')").each.first
        assert_equal(7, f.total_files)
      end
    end
  end

  def test_total_contributors
    fb = Factbase.new
    rate_limit_up
    Fbe.stub(:github_graph, Fbe::Graph::Fake.new) do
      Time.stub(:now, Time.parse('2024-09-29 21:00:00 UTC')) do
        VCR.use_cassette('dimensions-of-terrain/total-contributors') do
          load_it('dimensions-of-terrain', fb, Judges::Options.new({ 'repositories' => 'foo/foo,yegor256/empty-repo' }))
        end
        f = fb.query("(eq what 'dimensions-of-terrain')").each.first
        assert_equal(12, f.total_contributors)
      end
    end
  end

  def test_total_active_contributors
    fb = Factbase.new
    rate_limit_up
    Fbe.stub(:github_graph, Fbe::Graph::Fake.new) do
      Time.stub(:now, Time.parse('2024-09-29 21:00:00 UTC')) do
        VCR.use_cassette('dimensions-of-terrain/total-active-contributors') do
          load_it('dimensions-of-terrain', fb)
        end
        f = fb.query("(eq what 'dimensions-of-terrain')").each.first
        assert_equal(5, f.total_active_contributors)
      end
    end
  end

  def test_not_fill_props_if_quota_consumed
    fb = Factbase.new
    Fbe.stub(:github_graph, Fbe::Graph::Fake.new) do
      VCR.use_cassette('dimensions-of-terrain/not-fill-props-if-quota-consumed') do
        load_it('dimensions-of-terrain', fb, Judges::Options.new({ 'repositories' => 'foo/foo' }))
      end
      f = fb.query("(eq what 'dimensions-of-terrain')").each.first
      refute_nil(f)
      assert_nil(f['total_commits'])
      assert_nil(f['total_releases'])
      assert_nil(f['total_contributors'])
      assert_nil(f['total_active_contributors'])
      assert_nil(f['total_repositories'])
      assert_nil(f['total_files'])
      assert_nil(f['total_issues'])
      assert_nil(f['total_pulls'])
      assert_nil(f['total_forks'])
    end
  end
end
