# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
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
  Fbe.unmask_repos.each do |repo|
    json = Fbe.octo.repository(repo)
    next if json[:size].zero?
    commits += Fbe.github_graph.total_commits(*repo.split('/'), json[:default_branch])
  end
  { total_commits: commits }
end
