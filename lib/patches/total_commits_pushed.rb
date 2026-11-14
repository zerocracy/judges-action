# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/github_graph'

# rubocop:disable Elegant/NoComments
# shortcut: fbe 0.49.1 has no till, delete this file once fbe ships total_commits_pushed(owner, name, since, till)
# rubocop:enable Elegant/NoComments
class Fbe::Graph
  def total_commits_pushed(owner, name, since, till = Time.now)
    cursor = nil
    total = 0
    hoc = 0
    loop do
      after = "after: \"#{cursor}\", " unless cursor.nil?
      repository = query(
        <<~GRAPHQL
          {
            repository(owner: "#{owner}", name: "#{name}") {
              defaultBranchRef {
                target {
                  ... on Commit {
                    history(#{after}first: 100, since: "#{since.utc.iso8601}", until: "#{till.utc.iso8601}") {
                      totalCount
                      nodes {
                        additions
                        deletions
                      }
                      pageInfo {
                        endCursor
                        hasNextPage
                      }
                    }
                  }
                }
              }
            }
          }
        GRAPHQL
      ).to_h['repository']
      commits = repository&.dig('defaultBranchRef', 'target', 'history', 'nodes')
      hoc += commits.nil? ? 0 : commits.sum { (_1['additions'] || 0) + (_1['deletions'] || 0) }
      total = repository&.dig('defaultBranchRef', 'target', 'history', 'totalCount') || 0
      break unless repository&.dig('defaultBranchRef', 'target', 'history', 'pageInfo', 'hasNextPage')
      prev = cursor
      cursor = repository.dig('defaultBranchRef', 'target', 'history', 'pageInfo', 'endCursor')
      break if cursor.nil? || cursor == prev
    end
    {
      'commits' => total,
      'hoc' => hoc
    }
  end
end

class Fbe::Graph::Fake # rubocop:disable Elegant/OneClassPerFile
  def total_commits_pushed(_owner, _name, _since, _till = Time.now)
    {
      'commits' => 29,
      'hoc' => 1857
    }
  end
end
