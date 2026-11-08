# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'fbe/fb'
require 'fbe/octo'
require 'judges/options'
require 'loog'
require 'octokit'
require_relative '../test__helper'

require_relative '../../judges/quality-of-service/some_triage_time'

class TestSomeTriageTime < Jp::Test
  def test_skips_repository_when_repo_id_raises_fbe_error
    fact = Factbase.new.insert
    fact.since = Time.parse('2025-01-01 00:00:00 UTC')
    fact.when = Time.parse('2025-02-01 00:00:00 UTC')
    $judge = 'quality-of-service'
    $loog = Loog::NULL
    $global = {}
    $options = Judges::Options.new({ 'repositories' => 'foo/foo' })
    octo = Object.new
    octo.define_singleton_method(:off_quota?) { |**| false }
    octo.define_singleton_method(:repo_id_by_name) do |_name|
      raise(Fbe::Error, 'GitHub repository "foo/foo" is not accessible: Octokit::NotFound')
    end
    found = { items: [{ number: 1 }] }
    fb = Factbase.new
    result =
      Fbe.stub(:fb, fb) do
        Fbe.stub(:octo, octo) do
          Fbe.stub(:unmask_repos, proc { |&b| ['foo/foo'].each(&b) }) do
            Jp.stub(:qosearch, proc { found }) { some_triage_time(fact) }
          end
        end
      end
    assert_equal({ some_triage_time: [] }, result)
  end

  def test_skips_repository_when_not_found
    fact = Factbase.new.insert
    fact.since = Time.parse('2025-01-01 00:00:00 UTC')
    fact.when = Time.parse('2025-02-01 00:00:00 UTC')
    $judge = 'quality-of-service'
    $loog = Loog::NULL
    $global = {}
    $options = Judges::Options.new({ 'repositories' => 'foo/foo' })
    octo = Object.new
    octo.define_singleton_method(:off_quota?) { |**| false }
    octo.define_singleton_method(:repo_id_by_name) do |_name|
      raise(Octokit::NotFound)
    end
    found = { items: [{ number: 1 }] }
    fb = Factbase.new
    result =
      Fbe.stub(:fb, fb) do
        Fbe.stub(:octo, octo) do
          Fbe.stub(:unmask_repos, proc { |&b| ['foo/foo'].each(&b) }) do
            Jp.stub(:qosearch, proc { found }) { some_triage_time(fact) }
          end
        end
      end
    assert_equal({ some_triage_time: [] }, result)
  end

  def test_skips_repository_when_forbidden
    fact = Factbase.new.insert
    fact.since = Time.parse('2025-01-01 00:00:00 UTC')
    fact.when = Time.parse('2025-02-01 00:00:00 UTC')
    $judge = 'quality-of-service'
    $loog = Loog::NULL
    $global = {}
    $options = Judges::Options.new({ 'repositories' => 'foo/foo' })
    octo = Object.new
    octo.define_singleton_method(:off_quota?) { |**| false }
    octo.define_singleton_method(:repo_id_by_name) do |_name|
      raise(Octokit::Forbidden)
    end
    found = { items: [{ number: 1 }] }
    fb = Factbase.new
    result =
      Fbe.stub(:fb, fb) do
        Fbe.stub(:octo, octo) do
          Fbe.stub(:unmask_repos, proc { |&b| ['foo/foo'].each(&b) }) do
            Jp.stub(:qosearch, proc { found }) { some_triage_time(fact) }
          end
        end
      end
    assert_equal({ some_triage_time: [] }, result)
  end

  def test_uses_default_threshold_when_fbe_raises
    fact = Factbase.new.insert
    pmp = Object.new
    pmp.define_singleton_method(:quality) { pmp }
    pmp.define_singleton_method(:qos_min_triage_seconds) do
      raise(Fbe::Error, "There is no 'qos_min_triage_seconds' property in the 'quality' area")
    end
    result =
      Fbe.stub(:pmp, pmp) do
        Fbe.stub(:unmask_repos, proc { |&b| }) do
          some_triage_time(fact)
        end
      end
    assert_equal({ some_triage_time: [] }, result)
  end
end
