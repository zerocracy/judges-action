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
    json =
      begin
        Fbe.octo.repository(repo)
      rescue Octokit::NotFound, Octokit::Deprecated => e
        $loog.info("Repository #{repo} not found: #{e.message}")
        next
      rescue Octokit::Forbidden => e
        $loog.warn(
          "[#{$judge}] Access forbidden to #{repo} " \
          "(transient, will retry next cycle): #{e.class}: #{e.message}"
        )
        next
      end
    next if json[:size].nil? || json[:size].zero?
    repos << [*repo.split('/'), json[:default_branch]]
  rescue Octokit::NotFound, Octokit::Deprecated => e
    $loog.info("Repository not found for #{repo}: #{e.message}")
    next
  rescue Octokit::Forbidden => e
    $loog.warn(
      "[#{$judge}] Access forbidden to repository #{repo} " \
      "(transient, will retry next cycle): #{e.class}: #{e.message}"
    )
    next
  end
  { total_commits: repos.empty? ? 0 : Fbe.github_graph.total_commits(repos:).sum { _1['total_commits'] } }
end
