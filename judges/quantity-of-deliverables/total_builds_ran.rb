# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'

def total_builds_ran(fact)
  {
    total_builds_ran:
      Fbe.unmask_repos.sum do |repo|
        Fbe.octo.with_disable_auto_paginate do |octo|
          octo.repository_workflow_runs(
            repo,
            created: "#{fact.since.utc.iso8601[0..9]}..#{fact.when.utc.iso8601[0..9]}",
            per_page: 1
          )[:total_count]
        end
      rescue Octokit::NotFound, Octokit::Deprecated => e
        $loog.info("Workflow runs not found for #{repo}: #{e.message}")
        0
      rescue Octokit::Forbidden => e
        $loog.warn(
          "[#{$judge}] Access forbidden to workflow runs for #{repo} " \
          "(transient, will retry next cycle): #{e.class}: #{e.message}"
        )
        next
      end
  }
end
