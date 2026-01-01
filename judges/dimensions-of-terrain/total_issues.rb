# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/github_graph'
require 'fbe/unmask_repos'

# Total number of issues and pull requests for all repos
#
# This function is called from the "dimensions-of-terrain.rb".
#
# @param [Factbase::Fact] fact The fact just under processing
# @return [Hash] Map with keys as fact attributes and values as integers
def total_issues(_fact)
  issues = 0
  pulls = 0
  Fbe.unmask_repos do |repo|
    json = Fbe.github_graph.total_issues_and_pulls(*repo.split('/'))
    issues += json['issues']
    pulls += json['pulls']
  end
  { total_issues: issues, total_pulls: pulls }
end
