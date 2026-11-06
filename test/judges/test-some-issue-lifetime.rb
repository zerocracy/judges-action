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

  def test_drops_the_partial_list_when_the_quota_is_gone
    fact = Factbase.new.insert
    fact.since = Time.parse('2025-01-01 00:00:00 UTC')
    fact.when = Time.parse('2025-02-01 00:00:00 UTC')
    $judge = 'quality-of-service'
    $loog = Loog::NULL
    $global = {}
    $options = Judges::Options.new({ 'repositories' => 'foo/foo,foo/bar,foo/baz' })
    current = nil
    octo = Object.new
    octo.define_singleton_method(:off_quota?) { |**| current == 'foo/bar' }
    queries = []
    result =
      Fbe.stub(:octo, octo) do
        Fbe.stub(
          :unmask_repos,
          proc do |&b|
            %w[foo/foo foo/bar foo/baz].each do |r|
              current = r
              b.call(r)
            end
          end
        ) do
          Jp.stub(
            :qosearch,
            proc do |q, **|
              queries << q
              { items: [{ closed_at: fact.since + 3600, created_at: fact.since }] }
            end
          ) { some_issue_lifetime(fact) }
        end
      end
    assert_empty(result, 'a lifetime collected before the quota ended must not be reported')
    assert_equal(2, queries.size, 'no search may run after the quota is gone')
  end
end
