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

Fbe.conclude do
  quota_aware
  on '(and
    (or (eq what "pull-was-reviewed") (eq what "pull-was-merged"))
    (not (exists review_comments)))'
  consider do |f|
    begin
      repo = Fbe.octo.repo_name_by_id(f.repository)
    rescue Octokit::NotFound => e
      $loog.info("Failed to find repository #{f.repository}: #{e.message}")
      next
    end
    begin
      json = Fbe.octo.pull_request(repo, f.issue)
    rescue Octokit::NotFound => e
      $loog.info("Failed to find issue ##{f.issue} in #{repo}: #{e.message}")
      next
    end
    c = json[:review_comments]
    f.review_comments = c
    $loog.info("Found #{c} review comments in #{repo}##{f.issue} (what: #{f.what})")
  end
end

Fbe.octo.print_trace!
