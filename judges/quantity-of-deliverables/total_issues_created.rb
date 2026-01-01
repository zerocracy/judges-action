# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
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
  Fbe.unmask_repos do |repo|
    owner, name = repo.split('/')
    Fbe.github_graph.total_issues_created(owner, name, fact.since).then do |json|
      issues += json['issues'] + json['pulls']
      pulls += json['pulls']
    end
  end
  {
    total_issues_created: issues,
    total_pulls_submitted: pulls
  }
end
