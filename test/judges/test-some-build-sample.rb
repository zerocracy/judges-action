# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'judges/options'
require 'loog'
require_relative '../test__helper'

class TestSomeBuildSample < Jp::Test
  def test_says_that_the_runs_were_a_sample
    $judge = 'quality-of-service'
    $loog = Loog::Buffer.new
    $global = {}
    $options = Judges::Options.new({ 'repositories' => 'foo/foo' })
    fact = Struct.new(:since, :when).new(Time.parse('2024-08-02T21:00:00Z'), Time.parse('2024-08-09T21:00:00Z'))
    runs =
      (1..70).map do |i|
        {
          id: i, workflow_id: 1, status: 'completed', conclusion: 'success',
          run_started_at: Time.parse('2024-08-05T10:00:00Z')
        }
      end
    octo = Object.new
    octo.define_singleton_method(:off_quota?) { |**| false }
    octo.define_singleton_method(:repository_workflow_runs) { |*, **| { workflow_runs: runs } }
    octo.define_singleton_method(:workflow_run_usage) { |_repo, _id| { run_duration_ms: 900_000 } }
    load(File.join(__dir__, '../../judges/quality-of-service/some_build_success_rate.rb'))
    result =
      Fbe.stub(:octo, octo) do
        Fbe.stub(:unmask_repos, proc { |&b| b.call('foo/foo') }) { some_build_success_rate(fact) }
      end
    assert_equal(60, result[:some_build_success_rate].size)
    assert_includes($loog.to_s, 'sample of the window')
  end
end
