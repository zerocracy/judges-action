# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/github_graph'
require 'fbe/octo'
require_relative 'jp'

def Jp.closing_issues(repo, number)
  org, name = repo.split('/')
  issues = {}
  cursor = nil
  loop do
    page =
      Fbe.github_graph.query(
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
                    number
                    assignees(first: 100) {
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
    break if page.nil? || page['nodes'].nil?
    page['nodes'].each do |node|
      issues[node['number']] = node.dig('assignees', 'nodes').to_a.filter_map { |a| a['databaseId'] }
    end
    break unless page.dig('pageInfo', 'hasNextPage')
    cursor = page.dig('pageInfo', 'endCursor')
  end
  issues
rescue GraphQL::Client::Error, Octokit::NotFound, Octokit::Deprecated => e
  $loog.info("The closing issues of #{repo}##{number} are not available: #{e.message}")
  nil
rescue Octokit::Forbidden => e
  $loog.warn(
    "[#{$judge}] Access forbidden to the closing issues of #{repo}##{number} " \
    "(transient, will retry next cycle): #{e.class}: #{e.message}"
  )
  nil
end

def Jp.fill_hijacks(fact, closing, author)
  closing.values.reduce(Set.new, :merge).each { |who| fact.assignee = who }
  fact.hijacks = closing.count { |_, whos| !whos.empty? && !whos.include?(author) }
end
