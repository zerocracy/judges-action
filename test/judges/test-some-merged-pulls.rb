# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'judges/options'
require 'loog'
require_relative '../test__helper'

require_relative '../../judges/quality-of-service/some_merged_pulls'

class TestSomeMergedPulls < Jp::Test
  def test_keeps_the_counts_of_a_repository_when_a_later_search_fails
    fact = Factbase.new.insert
    fact.since = Time.parse('2025-01-01 00:00:00 UTC')
    fact.when = Time.parse('2025-02-01 00:00:00 UTC')
    $judge = 'quality-of-service'
    $loog = Loog::NULL
    $global = {}
    $options = Judges::Options.new({ 'repositories' => 'foo/foo,foo/bar' })
    octo = Object.new
    octo.define_singleton_method(:off_quota?) { |**| false }
    answers = [{ total_count: 10 }, { total_count: 3 }, nil]
    result =
      Fbe.stub(:octo, octo) do
        Fbe.stub(:unmask_repos, proc { |&b| %w[foo/foo foo/bar].each(&b) }) do
          Jp.stub(:qosearch, proc { |*| answers.shift }) { some_merged_pulls(fact) }
        end
      end
    assert_equal({ some_merged_pulls: [10], some_unmerged_pulls: [3] }, result)
  end

  def test_partitions_boundary_pulls_across_windows_including_subsecond_cutoffs
    $judge = 'quality-of-service'
    $loog = Loog::NULL
    $global = {}
    $options = Judges::Options.new({ 'repositories' => 'foo/foo' })
    Jp.qoreset
    items =
      {
        'merged' => %w[2024-08-09T20:59:59Z 2024-08-09T21:00:00Z 2024-08-23T21:00:00Z 2024-08-23T21:00:01Z],
        'unmerged' => %w[2024-08-09T21:00:00Z 2024-08-23T21:00:00Z 2024-08-23T21:00:01Z]
      }.transform_values { |ts| ts.map { |t| Time.parse(t) } }
    octo = boundary_octo(items)
    win = Struct.new(:since, :when)
    results =
      Fbe.stub(:octo, octo) do
        Fbe.stub(:unmask_repos, proc { |&b| b.call('foo/foo') }) do
          [
            some_merged_pulls(win.new(Time.parse('2024-08-02T21:00:00Z'), Time.parse('2024-08-09T21:00:00Z'))),
            some_merged_pulls(win.new(Time.parse('2024-08-09T21:00:00Z'), Time.parse('2024-08-23T21:00:00.700Z'))),
            some_merged_pulls(win.new(Time.parse('2024-08-23T21:00:00.700Z'), Time.parse('2024-08-30T21:00:00Z')))
          ]
        end
      end
    assert_equal([[1], [2], [1]], results.map { |res| res[:some_merged_pulls] })
    assert_equal([[0], [2], [1]], results.map { |res| res[:some_unmerged_pulls] })
  end

  private

  def boundary_octo(items)
    octo = Object.new
    octo.define_singleton_method(:off_quota?) { |**| false }
    octo.define_singleton_method(:rate_limit) { Struct.new(:remaining).new(30) }
    octo.define_singleton_method(:with_disable_auto_paginate) { |&b| b.call(octo) }
    octo.define_singleton_method(:search_issues) do |q, **|
      kind = q[/is:(merged|unmerged)/, 1]
      head = Time.parse(q[/closed:(\S+)\.\./, 1])
      tail = Time.parse(q[/closed:\S+\.\.(\S+)/, 1])
      matched = items.fetch(kind, []).grep(head..tail)
      { total_count: matched.size, items: matched }
    end
    octo
  end
end
