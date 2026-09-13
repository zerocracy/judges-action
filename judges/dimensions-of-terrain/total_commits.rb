# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/github_graph'
require 'fbe/octo'
require 'fbe/unmask_repos'
require 'net/http'
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
    next if json[:default_branch].nil?
    repos << [*repo.split('/'), json[:default_branch]]
  end
  begin
    { total_commits: repos.empty? ? 0 : Fbe.github_graph.total_commits(repos:).sum { _1['total_commits'] } }
  rescue GraphQL::Client::Error, Fbe::Error => e
    $loog.info("Batch commit count failed for #{repos.count} repos, retrying one by one: #{e.message}")
    { total_commits: count_commits_per_repo(repos) }
  rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNRESET, Errno::ETIMEDOUT => e
    $loog.warn(
      "[#{$judge}] Network error counting commits in #{repos.count} repositories " \
      "(transient, will retry next cycle), skipping total_commits: #{e.message}"
    )
    {}
  end
end

def count_commits_per_repo(repos)
  total = 0
  repos.each do |owner, name, branch|
    total += Fbe.github_graph.total_commits(repos: [[owner, name, branch]]).sum { _1['total_commits'] }
  rescue GraphQL::Client::Error, Fbe::Error,
    Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNRESET, Errno::ETIMEDOUT => e
    $loog.info("Skipping commits for #{owner}/#{name}: #{e.message}")
  end
  total
end
