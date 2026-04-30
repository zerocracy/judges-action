# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/github_graph'
require 'fbe/octo'
require 'fbe/unmask_repos'

def total_contributors(_fact)
  contributors = Set.new
  Fbe.unmask_repos do |repo|
    json = Fbe.octo.repository(repo)
    next if json[:size].nil? || json[:size].zero?
    owner, name = repo.split('/')
    contributors.merge(Fbe.github_graph.distinct_contributors(owner, name))
  end
  { total_contributors: contributors.count }
end
