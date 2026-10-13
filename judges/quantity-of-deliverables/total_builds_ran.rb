# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'
require_relative '../../lib/patches/unmask_repos'

def total_builds_ran(fact)
  total = 0
  available = false
  count =
    lambda do |repo, from, till|
      found =
        Fbe.octo.with_disable_auto_paginate do |octo|
          octo.repository_workflow_runs(repo, created: "#{from.utc.iso8601}..#{till.utc.iso8601}", per_page: 1)
        end[:total_count]
      return found if found < 2500
      if till - from < 120
        $loog.warn("[#{$judge}] GitHub caps the workflow runs of #{repo} at #{found} in #{from}..#{till}")
        return found
      end
      middle = from + ((till - from) / 2).floor
      count.call(repo, from, middle) + count.call(repo, middle + 1, till)
    end
  Fbe.unmask_repos.each do |repo|
    total += count.call(repo, fact.since, fact.when)
    available = true
  rescue Octokit::NotFound, Octokit::Deprecated => e
    $loog.info(
      "[#{$judge}] Workflow runs of #{repo} are not readable, " \
      "no total_builds_ran reported: #{e.class}: #{e.message}"
    )
    next
  rescue Octokit::Forbidden => e
    $loog.warn(
      "[#{$judge}] Access forbidden to workflow runs of #{repo}, " \
      "no total_builds_ran reported (will retry next cycle): #{e.class}: #{e.message}"
    )
    next
  end
  available ? { total_builds_ran: total } : {}
end
