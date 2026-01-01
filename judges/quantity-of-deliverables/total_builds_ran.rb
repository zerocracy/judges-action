# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'

# Calculates the total number of CI workflow runs executed across all monitored GitHub repositories.
# This function counts GitHub Actions workflow runs that were created after the 'since' date
# specified in the fact object, providing a metric for CI/CD activity over time.
#
# This function is called from the "quantity-of-deliverables.rb" using the incremate
# helper to collect this specific metric as part of deliverables quantity analysis.
#
# @param [Factbase::Fact] fact The fact object containing the 'since' timestamp
# @return [Hash] Map with total_builds_ran count as a key-value pair
# @see ../quantity-of-deliverables.rb Main judge that calls this function
def total_builds_ran(fact)
  total =
    Fbe.unmask_repos.sum do |repo|
      Fbe.octo.with_disable_auto_paginate do |octo|
        octo.repository_workflow_runs(repo, created: ">#{fact.since.utc.iso8601[0..9]}", per_page: 1)[:total_count]
      end
    end
  { total_builds_ran: total }
end
