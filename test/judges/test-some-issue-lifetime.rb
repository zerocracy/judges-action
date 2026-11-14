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

  def test_partitions_boundary_items_across_windows_including_subsecond_cutoffs
    $judge = 'quality-of-service'
    $loog = Loog::NULL
    $global = {}
    $options = Judges::Options.new({ 'repositories' => 'foo/foo' })
    Jp.qoreset
    items = {
      'issue' => [
        { closed_at: Time.parse('2024-08-09T20:59:59Z'), created_at: Time.parse('2024-08-09T19:59:59Z') },
        { closed_at: Time.parse('2024-08-09T21:00:00Z'), created_at: Time.parse('2024-08-09T19:00:00Z') },
        { closed_at: Time.parse('2024-08-23T21:00:00Z'), created_at: Time.parse('2024-08-23T18:00:00Z') },
        { closed_at: Time.parse('2024-08-23T21:00:01Z'), created_at: Time.parse('2024-08-23T17:00:01Z') }
      ],
      'pr' => [
        { closed_at: Time.parse('2024-08-09T21:00:00Z'), created_at: Time.parse('2024-08-09T20:00:00Z') },
        { closed_at: Time.parse('2024-08-23T21:00:00Z'), created_at: Time.parse('2024-08-23T19:00:00Z') },
        { closed_at: Time.parse('2024-08-23T21:00:01Z'), created_at: Time.parse('2024-08-23T18:00:01Z') }
      ]
    }
    octo = boundary_octo(items)
    win = Struct.new(:since, :when)
    results =
      Fbe.stub(:octo, octo) do
        Fbe.stub(:unmask_repos, proc { |&b| b.call('foo/foo') }) do
          [
            some_issue_lifetime(win.new(Time.parse('2024-08-02T21:00:00Z'), Time.parse('2024-08-09T21:00:00Z'))),
            some_issue_lifetime(win.new(Time.parse('2024-08-09T21:00:00Z'), Time.parse('2024-08-23T21:00:00.700Z'))),
            some_issue_lifetime(win.new(Time.parse('2024-08-23T21:00:00.700Z'), Time.parse('2024-08-30T21:00:00Z')))
          ]
        end
      end
    assert_equal([3600.0], results[0]['some_issue_lifetime'])
    assert_equal([7200.0, 10_800.0], results[1]['some_issue_lifetime'])
    assert_equal([14_400.0], results[2]['some_issue_lifetime'])
    assert_equal([3600.0, 7200.0, 10_800.0], results.flat_map { |res| res['some_pull_lifetime'] })
  end

  private

  def boundary_octo(items)
    octo = Object.new
    octo.define_singleton_method(:off_quota?) { |**| false }
    octo.define_singleton_method(:rate_limit) { Struct.new(:remaining).new(30) }
    octo.define_singleton_method(:with_disable_auto_paginate) { |&b| b.call(octo) }
    octo.define_singleton_method(:search_issues) do |q, **|
      kind = q[/type:(\S+)/, 1]
      head = Time.parse(q[/closed:(\S+)\.\./, 1])
      tail = Time.parse(q[/closed:\S+\.\.(\S+)/, 1])
      matched = items.fetch(kind, []).select { |item| item[:closed_at].between?(head, tail) }
      { total_count: matched.size, items: matched }
    end
    octo
  end
end
