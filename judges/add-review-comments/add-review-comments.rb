# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

# Judge that collects review comments count for pull requests.
# For pull requests that have been reviewed or merged but do not have
# a review_comments count recorded, this judge fetches the count from GitHub
# and stores it in the factbase.
#
# @note Uses Fbe.conclude to process pull requests that need comment counting
# @see https://github.com/yegor256/fbe/blob/master/lib/fbe/conclude.rb Implementation of Fbe.conclude

require 'octokit'
require 'fbe/octo'
require 'fbe/conclude'
require_relative '../../lib/issue_was_lost'

Fbe.conclude do
  on '(and
    (or (eq what "pull-was-reviewed") (eq what "pull-was-merged"))
    (absent review_comments)
    (absent stale)
    (absent tombstone)
    (absent done)
    (exists issue)
    (exists repository)
    (eq where "github"))'
  consider do |f|
    repo =
      begin
        Fbe.octo.repo_name_by_id(f.repository)
      rescue Octokit::NotFound => e
        $loog.info("Failed to find repository #{f.repository}: #{e.message}")
        f.stale = 'repository'
        next
      end
    json =
      begin
        Fbe.octo.pull_request(repo, f.issue)
      rescue Octokit::NotFound => e
        $loog.info("Failed to find issue ##{f.issue} in #{repo}: #{e.message}")
        Jp.issue_was_lost('github', f.repository, f.issue)
        next
      end
    c = json[:review_comments]
    f.review_comments = c
    $loog.info("Found #{c} review comments in #{repo}##{f.issue} (what: #{f.what})")
  end
end

Fbe.octo.print_trace!
