# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'

def total_builds_ran(fact)
  total = 0
  Fbe.unmask_repos.each do |repo|
    total +=
      Fbe.octo.with_disable_auto_paginate do |octo|
        octo.repository_workflow_runs(
          repo,
          created: "#{fact.since.utc.iso8601[0..9]}..#{fact.when.utc.iso8601[0..9]}",
          per_page: 1
        )[:total_count]
      end
  rescue Octokit::NotFound, Octokit::Deprecated => e
    $loog.info(
      "[#{$judge}] Workflow runs of #{repo} are not readable, " \
      "no total_builds_ran reported: #{e.class}: #{e.message}"
    )
    return {}
  rescue Octokit::Forbidden => e
    $loog.warn(
      "[#{$judge}] Access forbidden to workflow runs of #{repo}, " \
      "no total_builds_ran reported (will retry next cycle): #{e.class}: #{e.message}"
    )
    return {}
  end
  { total_builds_ran: total }
end
