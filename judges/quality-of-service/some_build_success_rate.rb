# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'
require_relative '../../lib/recovered'
require 'octokit'

def some_build_success_rate(fact)
  success = []
  duration = []
  ttrs = []
  failed = {}
  conclusions = %w[success failure]
  Fbe.unmask_repos do |repo|
    return {} if Fbe.octo.off_quota?
    workflows =
      begin
        Fbe.octo.repository_workflow_runs(
          repo, created: "#{fact.since.utc.iso8601}..#{fact.when.utc.iso8601}"
        )[:workflow_runs]
      rescue Octokit::NotFound, Octokit::Deprecated => e
        $loog.info("Workflow runs not found for #{repo}: #{e.message}")
        next
      rescue Octokit::TooManyRequests, Octokit::AbuseDetected => e
        $loog.warn("[#{$judge}] GitHub rate limit reached for #{repo}; leaving the metric for retry: #{e.message}")
        :retry
      rescue Octokit::Forbidden => e
        $loog.warn(
          "[#{$judge}] Access forbidden to workflow runs for #{repo} " \
          "(skipping inaccessible data): #{e.class}: #{e.message}"
        )
        next
      end
    return {} if workflows == :retry
    wfs = workflows.select { |json| json[:status] == 'completed' && conclusions.include?(json[:conclusion]) }.first(60)
    runs =
      wfs.filter_map do |json|
        break if Fbe.octo.off_quota?
        secs =
          begin
            ms = Fbe.octo.workflow_run_usage(repo, json[:id])[:run_duration_ms]
            next if ms.nil?
            ms / 1000.0
          rescue Octokit::NotFound, Octokit::Deprecated => e
            $loog.info("Workflow run usage not found for #{repo}##{json[:id]}: #{e.message}")
            next
          rescue Octokit::TooManyRequests, Octokit::AbuseDetected => e
            $loog.warn("[#{$judge}] GitHub rate limit reached for #{repo}; leaving the metric for retry: #{e.message}")
            :retry
          rescue Octokit::Forbidden => e
            $loog.warn(
              "[#{$judge}] Access forbidden to workflow run usage for #{repo}##{json[:id]} " \
              "(skipping inaccessible data): #{e.class}: #{e.message}"
            )
            next
          end
        return {} if secs == :retry
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
    failed.each do |wid, broke|
      recovery = Jp.recovered(repo, wid, fact.when)
      next if recovery.nil?
      ttrs << Integer(recovery - broke)
    end
    failed.clear
  end
  {
    some_build_success_rate: success,
    some_build_duration: duration,
    some_build_mttr: ttrs
  }
end
