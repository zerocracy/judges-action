# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/github_graph'
require 'fbe/octo'
require 'fbe/unmask_repos'
require 'net/http'
require 'octokit'

def total_commits_pushed(fact)
  commits = 0
  hoc = 0
  Fbe.unmask_repos do |repo|
    begin
      json = Fbe.octo.repository(repo)
      next if json[:size].nil? || json[:size].zero?
    rescue Octokit::NotFound, Octokit::Deprecated => e
      $loog.info("#{repo} can't be inspected: #{e.class}: #{e.message}")
      next
    rescue Octokit::Forbidden => e
      $loog.warn(
        "[#{$judge}] Access forbidden to #{repo} " \
        "(transient, will retry next cycle): #{e.class}: #{e.message}"
      )
      next
    end
    owner, name = repo.split('/')
    begin
      Fbe.github_graph.total_commits_pushed(owner, name, fact.since).then do |json|
        commits += json['commits']
        hoc += json['hoc']
      end
    rescue Octokit::NotFound, Octokit::Deprecated => e
      $loog.info("Can't count pushed commits in #{repo}: #{e.message}")
      next
    rescue Octokit::Forbidden => e
      $loog.warn(
        "[#{$judge}] Access forbidden to pushed commits in #{repo} " \
        "(transient, will retry next cycle): #{e.class}: #{e.message}"
      )
      next
    rescue GraphQL::Client::Error,
      Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNRESET, Errno::ETIMEDOUT => e
      $loog.warn(
        "[#{$judge}] Can't count pushed commits in #{repo} " \
        "(transient, will retry next cycle): #{e.class}: #{e.message}"
      )
      next
    end
  end
  {
    total_commits_pushed: commits,
    total_hoc_committed: hoc
  }
end
