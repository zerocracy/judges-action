# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'

def total_commits_pushed(fact)
  commits = 0
  hoc = 0
  Fbe.unmask_repos do |repo|
    next if Fbe.octo.repository(repo)[:size].zero?
    owner, name = repo.split('/')
    Fbe.github_graph.total_commits_pushed(owner, name, fact.since).then do |json|
      commits += json['commits']
      hoc += json['hoc']
    end
  end
  {
    total_commits_pushed: commits,
    total_hoc_committed: hoc
  }
end
