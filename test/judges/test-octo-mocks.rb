# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'judges/options'
require 'loog'
require_relative '../../lib/recovered'
require_relative '../test__helper'

class TestOctoMocks < Jp::Test
  def test_tolerates_mock_octo_without_off_quota_in_build_rate
    $judge = 'quality-of-service'
    $loog = Loog::NULL
    $global = {}
    $options = Judges::Options.new({ 'repositories' => 'foo/foo' })
    fact = Struct.new(:since, :when).new(Time.parse('2024-08-02T21:00:00Z'), Time.parse('2024-08-09T21:00:00Z'))
    octo = Object.new
    octo.define_singleton_method(:repository_workflow_runs) do |*|
      { workflow_runs: [] }
    end
    load(File.join(__dir__, '../../judges/quality-of-service/some_build_success_rate.rb'))
    result =
      Fbe.stub(:octo, octo) do
        Fbe.stub(:unmask_repos, proc { |&b| b.call('foo/foo') }) { some_build_success_rate(fact) }
      end
    assert_empty(result[:some_build_success_rate])
  end

  def test_tolerates_bare_mock_octo_without_off_quota_in_recovered
    recovery = Time.parse('2025-01-12 00:00:00 UTC')
    octo = Object.new
    octo.define_singleton_method(:workflow_runs) do |_repo, _workflow, **|
      { workflow_runs: [{ id: 8, updated_at: recovery }] }
    end
    found =
      Fbe.stub(:octo, octo) do
        Jp.recovered('foo/foo', 42, Time.parse('2025-01-10 00:00:00 UTC'), judge: 'quality-of-service', loog: Loog::NULL)
      end
    assert_equal(recovery, found)
  end

  def test_answers_nil_when_octo_lacks_workflow_runs_in_recovered
    octo = Object.new
    found =
      Fbe.stub(:octo, octo) do
        Jp.recovered('foo/foo', 42, Time.parse('2025-01-10 00:00:00 UTC'), judge: 'quality-of-service', loog: Loog::NULL)
      end
    assert_nil(found)
  end

  def test_active_contributors_returns_empty_when_search_fails
    $global = {}
    $local = {}
    $judge = 'dimensions-of-terrain'
    $options = Judges::Options.new({ 'repositories' => 'foo/foo' })
    $loog = Loog::NULL
    load(File.join(__dir__, '../../judges/dimensions-of-terrain/total_active_contributors.rb'))
    Fbe.stub(:unmask_repos, proc { |&b| b.call('foo/foo') }) do
      Jp.stub(:qosearch, nil) do
        Factbase.new.insert.then do |f|
          f.what = 'dimensions-of-terrain'
          f.when = Time.parse('2024-09-29 21:00:00 UTC')
          assert_empty(total_active_contributors(f))
        end
      end
    end
  end
end
