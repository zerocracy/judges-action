# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'judges/options'
require 'loog'
require_relative '../test__helper'

require_relative '../../judges/quality-of-service/some_issue_lifetime'

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

  def test_some_issue_lifetime_searches_each_second_in_one_window_only
    $loog = Loog::NULL
    load(File.join(__dir__, '../../judges/quality-of-service/some_issue_lifetime.rb'))
    Jp.qoreset
    queries = []
    octo = Object.new
    octo.define_singleton_method(:off_quota?) { |**| false }
    octo.define_singleton_method(:rate_limit) { Struct.new(:remaining).new(30) }
    octo.define_singleton_method(:with_disable_auto_paginate) { |&block| block.call(octo) }
    octo.define_singleton_method(:search_issues) do |q, **|
      queries << q
      { total_count: 0, incomplete_results: false, items: [] }
    end
    window = Struct.new(:since, :when)
    Fbe.stub(:octo, octo) do
      Fbe.stub(:unmask_repos, ->(&block) { block.call('foo/foo') }) do
        some_issue_lifetime(window.new(Time.parse('2024-08-02T21:00:00Z'), Time.parse('2024-08-09T21:00:00Z')))
        some_issue_lifetime(window.new(Time.parse('2024-08-09T21:00:00Z'), Time.parse('2024-08-16T21:00:00Z')))
        some_issue_lifetime(window.new(Time.parse('2024-08-16T21:00:00Z'), Time.parse('2024-08-23T21:00:00.700Z')))
      end
    end
    assert_equal(
      [
        'repo:foo/foo type:issue closed:2024-08-02T21:00:00Z..2024-08-09T20:59:59Z',
        'repo:foo/foo type:pr closed:2024-08-02T21:00:00Z..2024-08-09T20:59:59Z',
        'repo:foo/foo type:issue closed:2024-08-09T21:00:00Z..2024-08-16T20:59:59Z',
        'repo:foo/foo type:pr closed:2024-08-09T21:00:00Z..2024-08-16T20:59:59Z',
        'repo:foo/foo type:issue closed:2024-08-16T21:00:00Z..2024-08-23T20:59:59Z',
        'repo:foo/foo type:pr closed:2024-08-16T21:00:00Z..2024-08-23T20:59:59Z'
      ],
      queries
    )
  end
end
