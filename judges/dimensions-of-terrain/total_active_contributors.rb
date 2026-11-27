# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'
require_relative '../../lib/patches/unmask_repos'
require_relative '../../lib/qos_search'

COMMITS_PAGE = 100

def total_active_contributors(fact)
  seen = Set.new
  Fbe.unmask_repos do |repo|
    commits =
      begin
        Jp.qosearch(
          "repo:#{repo} author-date:>#{(fact.when - (30 * 24 * 60 * 60)).iso8601[0..9]}",
          method: :search_commits
        )
      rescue Octokit::NotFound, Octokit::Deprecated => e
        $loog.info("Commits not found for #{repo}: #{e.message}")
        next
      rescue Octokit::TooManyRequests => e
        $loog.warn("[#{$judge}] API rate limit exhausted, stopping the scan: #{e.class}: #{e.message}")
        break
      rescue Octokit::Forbidden => e
        $loog.warn(
          "[#{$judge}] Access forbidden to commit search for #{repo} " \
          "(transient, will retry next cycle): #{e.class}: #{e.message}"
        )
        next
      end
    return {} if commits.nil?
    if commits[:items].count >= COMMITS_PAGE
      $loog.info(
        "[#{$judge}] The commit search of #{repo} answers one page of #{COMMITS_PAGE} and has that many, " \
        'so the total would be a floor and not a count'
      )
      return {}
    end
    commits[:items].each do |commit|
      date = commit.dig(:commit, :author, :date)
      next if !date.nil? && Time.parse(date.to_s) > fact.when
      author = commit.dig(:author, :id)
      seen << author unless author.nil?
    end
  end
  { total_active_contributors: seen.count }
end
