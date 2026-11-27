# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/github_graph'

class Fbe::Graph
  def total_issues_created(owner, name, since)
    window = "#{(since.begin + 1).utc.iso8601}..#{since.end.utc.iso8601}"
    result = query(
      <<~GRAPHQL
        {
          issues: search(
            query: "repo:#{owner}/#{name} type:issue created:#{window}",
            type: ISSUE
          ) {
            issueCount
          },
          pulls: search(
            query: "repo:#{owner}/#{name} type:pr created:#{window}",
            type: ISSUE
          ) {
            issueCount
          }
        }
      GRAPHQL
    ).to_h
    {
      'issues' => result.dig('issues', 'issueCount') || 0,
      'pulls' => result.dig('pulls', 'issueCount') || 0
    }
  end
end
