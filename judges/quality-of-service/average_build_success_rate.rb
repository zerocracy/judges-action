# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'

# Workflow runs:
#
# This function is called from the "quality-of-service.rb".
#
# @param [Factbase::Fact] fact The fact just under processing
# @return [Hash] Map with keys as fact attributes and values as integers
def average_build_success_rate(fact)
  total = 0
  success = 0
  duration = 0
  ttrs = []
  failed = {}
  Fbe.unmask_repos.each do |repo|
    Fbe.octo.repository_workflow_runs(repo, created: ">#{fact.since.utc.iso8601[0..9]}")[:workflow_runs].each do |json|
      workflow_id = json[:workflow_id]
      run_duration = (Fbe.octo.workflow_run_usage(repo, json[:id])[:run_duration_ms] || 0) / 1000
      completed = json[:run_started_at] + run_duration
      if json[:conclusion] == 'failure' && failed[workflow_id].nil?
        failed[workflow_id] = completed
      elsif json[:conclusion] == 'success' && failed[workflow_id]
        ttrs << (completed - failed[workflow_id]).to_i
        failed.delete(workflow_id)
      end
      total += 1
      success += json[:conclusion] == 'success' ? 1 : 0
      duration += run_duration
    end
  end
  {
    average_build_success_rate: total.zero? ? 0 : success.to_f / total,
    average_build_duration: total.zero? ? 0 : duration.to_f / total,
    average_build_mttr: ttrs.any? ? ttrs.sum / ttrs.size : 0
  }
end
