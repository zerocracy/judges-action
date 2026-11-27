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

  def test_samples_boundary_pulls_in_exactly_one_window_including_subsecond_cutoffs
    $judge = 'quality-of-service'
    $loog = Loog::NULL
    $global = {}
    $options = Judges::Options.new({ 'repositories' => 'foo/foo' })
    Jp.qoreset
    closed = {
      1 => Time.parse('2024-08-09T20:59:59Z'),
      2 => Time.parse('2024-08-09T21:00:00Z'),
      3 => Time.parse('2024-08-23T21:00:00Z'),
      4 => Time.parse('2024-08-23T21:00:01Z')
    }
    octo = boundary_octo(closed)
    win = Struct.new(:since, :when)
    results =
      Fbe.stub(:octo, octo) do
        Fbe.stub(:unmask_repos, proc { |&b| b.call('foo/foo') }) do
          [
            some_pull_hoc_size(win.new(Time.parse('2024-08-02T21:00:00Z'), Time.parse('2024-08-09T21:00:00Z'))),
            some_pull_hoc_size(win.new(Time.parse('2024-08-09T21:00:00Z'), Time.parse('2024-08-23T21:00:00.700Z'))),
            some_pull_hoc_size(win.new(Time.parse('2024-08-23T21:00:00.700Z'), Time.parse('2024-08-30T21:00:00Z')))
          ]
        end
      end
    assert_equal([[10], [20, 30], [40]], results.map { |res| res[:some_pull_hoc_size] })
    assert_equal(4, results.sum { |res| res[:some_pull_files_size].size })
  end

  private

  def boundary_octo(closed)
    octo = Object.new
    octo.define_singleton_method(:off_quota?) { |**| false }
    octo.define_singleton_method(:rate_limit) { Struct.new(:remaining).new(30) }
    octo.define_singleton_method(:with_disable_auto_paginate) { |&b| b.call(octo) }
    octo.define_singleton_method(:search_issues) do |q, **|
      head = Time.parse(q[/closed:(\S+)\.\./, 1])
      tail = Time.parse(q[/closed:\S+\.\.(\S+)/, 1])
      matched = closed.select { |_, at| at.between?(head, tail) }.keys.map { |num| { number: num } }
      { total_count: matched.size, items: matched }
    end
    octo.define_singleton_method(:pull_request) do |_repo, num|
      { number: num, additions: num * 10, deletions: 0, changed_files: 1 }
    end
    octo
  end
end
