# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'

# Total number of CI builds executed in all repositories from since
#
# This function is called from the "quantity-of-deliverables.rb".
#
# @param [Factbase::Fact] fact The fact just under processing
# @return [Hash] Map with keys as fact attributes and values as integers
def total_builds_ran(fact)
  total =
    Fbe.unmask_repos.sum do |repo|
      Fbe.octo.repository_workflow_runs(repo, created: ">#{fact.since.utc.iso8601[0..9]}")[:total_count]
    end
  { total_builds_ran: total }
end
