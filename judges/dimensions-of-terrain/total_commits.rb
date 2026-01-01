# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/github_graph'
require 'fbe/unmask_repos'

# Total number of commits for all repos.
#
# This function is called from the "dimensions-of-terrain.rb".
#
# @param [Factbase::Fact] fact The fact just under processing
# @return [Hash] Map with keys as fact attributes and values as integers
def total_commits(_fact)
  commits = 0
  repos = []
  Fbe.unmask_repos do |repo|
    json = Fbe.octo.repository(repo)
    next if json[:size].zero?
    repos << [*repo.split('/'), json[:default_branch]]
  end
  commits = Fbe.github_graph.total_commits(repos:).sum { _1['total_commits'] } unless repos.empty?
  { total_commits: commits }
end
