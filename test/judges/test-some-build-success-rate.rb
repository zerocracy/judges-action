# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'judges/options'
require 'loog'
require_relative '../test__helper'

class TestSomeBuildSuccessRate < Jp::Test
  def test_dont_pair_failure_with_success_on_another_branch
    $judge = 'quality-of-service'
    $loog = Loog::NULL
    $global = {}
    $options = Judges::Options.new({ 'repositories' => 'foo/foo' })
    fact = Struct.new(:since, :when).new(Time.parse('2024-08-02T21:00:00Z'), Time.parse('2024-08-09T21:00:00Z'))
    started = Time.parse('2024-08-05T10:00:00Z')
    octo = Object.new
    octo.define_singleton_method(:off_quota?) { |**| false }
    octo.define_singleton_method(:with_disable_auto_paginate) { |&b| b.call(self) }
    octo.define_singleton_method(:workflow_runs) { |*, **| { workflow_runs: [] } }
    octo.define_singleton_method(:workflow_run_usage) { |*| { run_duration_ms: 60_000 } }
    octo.define_singleton_method(:repository_workflow_runs) do |*|
      {
        workflow_runs: [
          {
            id: 1, workflow_id: 7, head_branch: 'фича-a', status: 'completed',
            conclusion: 'failure', run_started_at: started
          },
          {
            id: 2, workflow_id: 7, head_branch: 'master', status: 'completed',
            conclusion: 'success', run_started_at: started + 36_000
          }
        ]
      }
    end
    load(File.join(__dir__, '../../judges/quality-of-service/some_build_success_rate.rb'))
    result =
      Fbe.stub(:octo, octo) do
        Fbe.stub(:unmask_repos, proc { |&b| b.call('foo/foo') }) { some_build_success_rate(fact) }
      end
    assert_empty(result[:some_build_mttr], 'a failure on one branch is repaired by a success on another')
  end
end
