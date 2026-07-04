# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'

def some_build_success_rate(fact)
  success = []
  duration = []
  ttrs = []
  failed = {}
  Fbe.unmask_repos do |repo|
    workflows =
      begin
        Fbe.octo.repository_workflow_runs(
          repo, created: "#{fact.since.utc.iso8601}..#{fact.when.utc.iso8601}"
        )[:workflow_runs]
      rescue Octokit::NotFound, Octokit::Deprecated, Octokit::TooManyRequests => e
        $loog.info("Workflow runs not found for #{repo}: #{e.message}")
        next
      rescue Octokit::Forbidden => e
        $loog.warn(
          "[#{$judge}] Access forbidden to workflow runs for #{repo} " \
          "(transient, will retry next cycle): #{e.class}: #{e.message}"
        )
        next
      end
    wfs = workflows.select { |json| json[:status] == 'completed' && !json[:conclusion].nil? }.first(60)
    runs =
      wfs.map do |json|
        secs =
          begin
            (Fbe.octo.workflow_run_usage(repo, json[:id])[:run_duration_ms] || 0) / 1000
          rescue Octokit::NotFound, Octokit::Deprecated, Octokit::TooManyRequests => e
            $loog.info("Workflow run usage not found for #{repo}##{json[:id]}: #{e.message}")
            0
          rescue Octokit::Forbidden => e
            $loog.warn(
              "[#{$judge}] Access forbidden to workflow run usage for #{repo}##{json[:id]} " \
              "(transient, will retry next cycle): #{e.class}: #{e.message}"
            )
            0
          end
        { json: json, secs: secs, completed: json[:run_started_at] + secs }
      end
    runs.sort_by! { _1[:completed] }
    runs.each do |item|
      item => { json:, secs:, completed: }
      wid = json[:workflow_id]
      if json[:conclusion] == 'failure' && failed[wid].nil?
        failed[wid] = completed
      elsif json[:conclusion] == 'success' && failed[wid]
        ttrs << Integer(completed - failed[wid])
        failed.delete(wid)
      end
      success << (json[:conclusion] == 'success' ? 1 : 0)
      duration << secs
    end
  end
  {
    some_build_success_rate: success,
    some_build_duration: duration,
    some_build_mttr: ttrs
  }
end
