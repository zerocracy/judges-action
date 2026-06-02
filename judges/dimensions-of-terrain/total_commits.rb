# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/github_graph'
require 'fbe/octo'

def total_commits(_fact)
  guard = $terrainguard
  commits = 0
  repos = []
  guard.eachrepo do |repo|
    json = guard.repository(repo)
    next if json.nil?
    next if json[:size].nil? || json[:size].zero?
    repos << [*repo.split('/'), json[:default_branch]]
  end
  commits = Fbe.github_graph.total_commits(repos:).sum { _1['total_commits'] } unless repos.empty?
  { total_commits: commits }
end
