# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'judges/options'
require 'loog'
require_relative '../test__helper'

class TestSomeBuildQuota < Jp::Test
  def test_reports_nothing_when_the_quota_is_gone
    $judge = 'quality-of-service'
    $loog = Loog::NULL
    $global = {}
    $options = Judges::Options.new({ 'repositories' => 'foo/foo' })
    fact = Struct.new(:since, :when).new(Time.parse('2024-08-02T21:00:00Z'), Time.parse('2024-08-09T21:00:00Z'))
    octo = Object.new
    octo.define_singleton_method(:off_quota?) { |**| true }
    octo.define_singleton_method(:repository_workflow_runs) { |*| raise(RuntimeError, 'the quota check did not stop us') }
    load(File.join(__dir__, '../../judges/quality-of-service/some_build_success_rate.rb'))
    result =
      Fbe.stub(:octo, octo) do
        Fbe.stub(:unmask_repos, proc { |&b| b.call('foo/foo') }) { some_build_success_rate(fact) }
      end
    assert_empty(result)
  end
end
