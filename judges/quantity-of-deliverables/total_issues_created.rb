# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'

# Number of issues and pull requests created:
#
# This function is called from the "quantity-of-deliverables.rb".
#
# @param [Factbase::Fact] fact The fact just under processing
# @return [Hash] Map with keys as fact attributes and values as integers
def total_issues_created(fact)
  issues = 0
  pulls = 0
  Fbe.unmask_repos.each do |repo|
    Fbe.octo.list_issues(repo, since: ">#{fact.since.utc.iso8601[0..9]}").each do |json|
      issues += 1
      pulls += 1 unless json[:pull_request].nil?
    end
  end
  {
    total_issues_created: issues,
    total_pulls_submitted: pulls
  }
end
