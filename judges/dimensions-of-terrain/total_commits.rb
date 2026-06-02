# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/github_graph'
require 'fbe/octo'
require 'fbe/unmask_repos'

def total_commits(_fact)
  repos = []
  Fbe.unmask_repos do |repo|
    json = Fbe.octo.repository(repo)
    next if json[:size].nil? || json[:size].zero?
    repos << [*repo.split('/'), json[:default_branch]]
  end
  { total_commits: repos.empty? ? 0 : Fbe.github_graph.total_commits(repos:).sum { _1['total_commits'] } }
end
