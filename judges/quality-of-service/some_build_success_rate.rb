# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'

# Workflow runs:
#
# This function is called from the "quality-of-service.rb".
#
# @param [Factbase::Fact] fact The fact just under processing
# @return [Hash] Map with keys as fact attributes and values as integers
def some_build_success_rate(fact)
  success = []
  duration = []
  ttrs = []
  failed = {}
  Fbe.unmask_repos do |repo|
    workflow_runs =
      Fbe.octo.repository_workflow_runs(
        repo, created: "#{fact.since.utc.iso8601}..#{fact.when.utc.iso8601}"
      )[:workflow_runs].first(60).map do |json|
        run_duration = (Fbe.octo.workflow_run_usage(repo, json[:id])[:run_duration_ms] || 0) / 1000
        { json: json, run_duration: run_duration, completed: json[:run_started_at] + run_duration }
      end
    workflow_runs.sort_by! { _1[:completed] }
    workflow_runs.each do |item|
      item => { json:, run_duration:, completed: }
      workflow_id = json[:workflow_id]
      if json[:conclusion] == 'failure' && failed[workflow_id].nil?
        failed[workflow_id] = completed
      elsif json[:conclusion] == 'success' && failed[workflow_id]
        ttrs << (completed - failed[workflow_id]).to_i
        failed.delete(workflow_id)
      end
      success << (json[:conclusion] == 'success' ? 1 : 0)
      duration << run_duration
    end
  end
  {
    some_build_success_rate: success,
    some_build_duration: duration,
    some_build_mttr: ttrs
  }
end
