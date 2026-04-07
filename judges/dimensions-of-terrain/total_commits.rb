# frozen_string_literal: true

require 'fbe/github_graph'
# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'

def total_commits(_fact)
  commits = 0
  repos = []
  Fbe.unmask_repos do |repo|
    json = Fbe.octo.repository(repo)
    next if json[:size].nil? || json[:size].zero?
    repos << [*repo.split('/'), json[:default_branch]]
  end
  commits = Fbe.github_graph.total_commits(repos:).sum { _1['total_commits'] } unless repos.empty?
  { total_commits: commits }
end
