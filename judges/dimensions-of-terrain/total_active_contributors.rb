# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'
require_relative '../../lib/patches/unmask_repos'
require_relative '../../lib/qos_search'

def total_active_contributors(fact)
  seen = Set.new
  Fbe.unmask_repos do |repo|
    commits =
      begin
        Jp.qosearch(
          "repo:#{repo} author-date:>#{(fact.when - (30 * 24 * 60 * 60)).iso8601[0..9]}",
          method: :search_commits
        )
      rescue Octokit::NotFound, Octokit::Deprecated, Octokit::TooManyRequests => e
        $loog.info("Commits not found for #{repo}: #{e.message}")
        next
      rescue Octokit::Forbidden => e
        $loog.warn(
          "[#{$judge}] Access forbidden to commit search for #{repo} " \
          "(transient, will retry next cycle): #{e.class}: #{e.message}"
        )
        next
      end
    next if commits.nil?
    commits[:items].each do |commit|
      author = commit.dig(:author, :id)
      seen << author unless author.nil?
    end
  rescue Octokit::NotFound, Octokit::Deprecated, Octokit::TooManyRequests => e
    $loog.info("Search commits not found for #{repo}: #{e.message}")
    next
  rescue Octokit::Forbidden => e
    $loog.warn(
      "[#{$judge}] Access forbidden to search commits in #{repo} " \
      "(transient, will retry next cycle): #{e.class}: #{e.message}"
    )
    next
  end
  { total_active_contributors: seen.count }
end
