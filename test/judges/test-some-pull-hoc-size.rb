# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'judges/options'
require 'loog'
require_relative '../fake_github'
require_relative '../test__helper'

require_relative '../../judges/quality-of-service/some_pull_hoc_size'

class TestSomePullHocSize < Jp::Test
  def test_records_zero_when_the_pull_has_no_changed_files
    fact = Factbase.new.insert
    fact.since = Time.parse('2025-01-01 00:00:00 UTC')
    fact.when = Time.parse('2025-02-01 00:00:00 UTC')
    $global = {}
    $loog = Loog::NULL
    $options = Judges::Options.new({ 'repositories' => 'foo/foo' })
    found = { items: [{ id: 1, number: 10 }] }
    result =
      Jp::FakeGithub.new(
        'GET /rate_limit' => { resources: { search: { remaining: 30, limit: 30 } }, rate: { remaining: 1000 } },
        'GET /repos/foo/foo' => { id: 42, full_name: 'foo/foo' },
        'GET /repos/foo/foo/pulls/10' => { number: 10, additions: 5, deletions: 3 }
      ).run { Jp.stub(:qosearch, found) { some_pull_hoc_size(fact) } }
    assert_equal([8], result[:some_pull_hoc_size])
    assert_equal([0], result[:some_pull_files_size])
  end

  def test_some_pull_hoc_size_searches_each_second_in_one_window_only
    $loog = Loog::NULL
    load(File.join(__dir__, '../../judges/quality-of-service/some_pull_hoc_size.rb'))
    Jp.qoreset
    queries = []
    octo = Object.new
    octo.define_singleton_method(:off_quota?) { |**| false }
    octo.define_singleton_method(:repo_id_by_name) { |*| 42 }
    octo.define_singleton_method(:rate_limit) { Struct.new(:remaining).new(30) }
    octo.define_singleton_method(:with_disable_auto_paginate) { |&block| block.call(octo) }
    octo.define_singleton_method(:search_issues) do |q, **|
      queries << q
      { total_count: 0, incomplete_results: false, items: [] }
    end
    window = Struct.new(:since, :when)
    Fbe.stub(:octo, octo) do
      Fbe.stub(:unmask_repos, ->(&block) { block.call('foo/foo') }) do
        some_pull_hoc_size(window.new(Time.parse('2024-08-02T21:00:00Z'), Time.parse('2024-08-09T21:00:00Z')))
        some_pull_hoc_size(window.new(Time.parse('2024-08-09T21:00:00Z'), Time.parse('2024-08-16T21:00:00Z')))
        some_pull_hoc_size(window.new(Time.parse('2024-08-16T21:00:00Z'), Time.parse('2024-08-23T21:00:00.700Z')))
      end
    end
    assert_equal(
      [
        'repo:foo/foo type:pr is:merged closed:2024-08-02T21:00:00Z..2024-08-09T20:59:59Z',
        'repo:foo/foo type:pr is:merged closed:2024-08-09T21:00:00Z..2024-08-16T20:59:59Z',
        'repo:foo/foo type:pr is:merged closed:2024-08-16T21:00:00Z..2024-08-23T20:59:59Z'
      ],
      queries
    )
  end
end
