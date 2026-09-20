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
  return { total_commits: 0 } if repos.empty?
  errors = [
    GraphQL::Client::Error, Fbe::Error, Net::OpenTimeout, Net::ReadTimeout,
    SocketError, Errno::ECONNRESET, Errno::ETIMEDOUT
  ]
  begin
    { total_commits: Fbe.github_graph.total_commits(repos:).sum { _1['total_commits'] } }
  rescue *errors => e
    $loog.warn(
      "[#{$judge}] Can't count commits in #{repos.count} repositories at once, " \
      "counting them one by one: #{e.class}: #{e.message}"
    )
    counted =
      repos.filter_map do |owner, name, branch|
        Fbe.github_graph.total_commits(owner, name, branch)
      rescue *errors => error
        $loog.warn(
          "[#{$judge}] Can't count commits in #{owner}/#{name} at #{branch} " \
          "(transient, will retry next cycle): #{error.class}: #{error.message}"
        )
        nil
      end
    counted.empty? ? {} : { total_commits: counted.sum }
  end
end
