# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/github_graph'
require 'fbe/octo'
require_relative 'jp'

def Jp.closing_issues(repo, number)
  graph = Fbe.github_graph
  return if graph.nil?
  org, name = repo.split('/')
  issues = {}
  cursor = nil
  seen = Set.new
  loop do
    page =
      graph.query(
        <<~GRAPHQL
          {
            repository(owner: "#{org}", name: "#{name}") {
              pullRequest(number: #{number}) {
                closingIssuesReferences(first: 100#{%(, after: "#{cursor}") if cursor}) {
                  pageInfo {
                    hasNextPage
                    endCursor
                  }
                  nodes {
                    id
                    assignees(first: 10) {
                      nodes {
                        databaseId
                      }
                    }
                  }
                }
              }
            }
          }
        GRAPHQL
      )&.to_h&.dig('repository', 'pullRequest', 'closingIssuesReferences')
    return unless page && page['nodes'] && !page.dig('pageInfo', 'hasNextPage').nil?
    return unless page['nodes'].all? do |node|
      users = node&.dig('assignees', 'nodes')
      next false unless users && node['id']
      ids = users.map { |user| user&.fetch('databaseId', nil) }
      next false if ids.any?(&:nil?)
      issues[node['id']] = ids
      true
    end
    break unless page.dig('pageInfo', 'hasNextPage')
    cursor = page.dig('pageInfo', 'endCursor')
    return unless cursor && seen.add?(cursor)
  end
  issues
rescue GraphQL::Client::Error, Octokit::NotFound, Octokit::Deprecated => e
  $loog.info("The closing issues of #{repo}##{number} are not available: #{e.message}")
  nil
rescue Octokit::Forbidden, Octokit::Unauthorized, Octokit::TooManyRequests, Octokit::ServerError,
  Faraday::TimeoutError, Faraday::ConnectionFailed => e
  $loog.warn(
    "[#{$judge}] Access forbidden to the closing issues of #{repo}##{number} " \
    "(transient, will retry next cycle): #{e.class}: #{e.message}"
  )
  nil
end

def Jp.fill_hijacks(fact, closing, author)
  assigned = closing.values.flatten
  assigned.uniq!
  return if author.nil? && !assigned.empty?
  (assigned - Array(fact['assignee'])).each { |who| fact.assignee = who }
  fact.hijacks = closing.count { |_, assignees| !assignees.empty? && !assignees.include?(author) }
end
