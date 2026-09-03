# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/github_graph'
require 'fbe/octo'
require 'fbe/unmask_repos'
require_relative '../../lib/patches/unmask_repos'

def total_commits(_fact)
  repos = []
  Fbe.unmask_repos do |repo|
    begin
      json = Fbe.octo.repository(repo)
    rescue Octokit::NotFound, Octokit::Deprecated => e
      $loog.info("Repository #{repo} not found: #{e.message}")
      next
    rescue Octokit::Forbidden => e
      $loog.warn(
        "[#{$judge}] Repository #{repo} forbidden (transient, will retry next cycle): #{e.class}: #{e.message}"
      )
      next
    end
    next if json[:size].nil? || json[:size].zero?
    repos << [*repo.split('/'), json[:default_branch]]
  end
  {
    total_commits:
    begin
      repos.empty? ? 0 : Fbe.github_graph.total_commits(repos:).sum { _1['total_commits'] }
    rescue GraphQL::Client::Error, Octokit::NotFound, Octokit::Deprecated => e
      $loog.info("Can't count total commits: #{e.message}")
      0
    rescue Octokit::Forbidden => e
      $loog.warn("[#{$judge}] Can't count total commits (transient, will retry next cycle): #{e.class}: #{e.message}")
      0
    rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNRESET, Errno::ETIMEDOUT => e
      $loog.warn("[#{$judge}] Network error counting commits: #{e.message}")
      0
    end
  }
end
