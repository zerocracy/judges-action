# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'judges/options'
require 'loog'
require_relative '../test__helper'

class TestSomeBuildMttr < Jp::Test
  def test_measures_from_the_end_of_a_long_failed_run
    assert_equal(
      [900],
      mttr(['failure', '2024-08-07T10:00:00Z', 1_800_000], ['success', '2024-08-07T10:40:00Z', 300_000]),
      'The recovery must be measured from 10:30, when the failed run ended, to 10:45'
    )
  end

  def test_measures_to_the_end_of_a_long_successful_run
    assert_equal(
      [1680],
      mttr(['failure', '2024-08-07T10:00:00Z', 120_000], ['success', '2024-08-07T10:10:00Z', 1_200_000]),
      'The recovery must be measured from 10:02 to 10:30, when the successful run ended'
    )
  end

  def test_measures_from_the_end_of_the_first_of_two_failed_runs
    assert_equal(
      [2400],
      mttr(
        ['failure', '2024-08-07T10:00:00Z', 1_800_000],
        ['failure', '2024-08-07T10:40:00Z', 300_000],
        ['success', '2024-08-07T11:00:00Z', 600_000]
      ),
      'The recovery must be measured from 10:30, when the first failed run ended, to 11:10'
    )
  end

  private

  def mttr(*runs)
    $judge = 'quality-of-service'
    $loog = Loog::NULL
    $global = {}
    $options = Judges::Options.new({ 'repositories' => 'foo/foo' })
    fact = Struct.new(:since, :when).new(Time.parse('2024-08-02T21:00:00Z'), Time.parse('2024-08-09T21:00:00Z'))
    jsons =
      runs.each_with_index.map do |(conclusion, start, _), i|
        {
          id: i + 1, status: 'completed', conclusion:, workflow_id: 101,
          run_started_at: Time.parse(start)
        }
      end
    octo = Object.new
    octo.define_singleton_method(:off_quota?) { |**| false }
    octo.define_singleton_method(:repository_workflow_runs) { |*, **| { workflow_runs: jsons } }
    octo.define_singleton_method(:workflow_run_usage) { |_, id| { run_duration_ms: runs[id - 1][2] } }
    load(File.join(__dir__, '../../judges/quality-of-service/some_build_success_rate.rb'))
    Fbe.stub(:octo, octo) do
      Fbe.stub(:unmask_repos, proc { |&b| b.call('foo/foo') }) { some_build_success_rate(fact) }
    end[:some_build_mttr]
  end
end
