# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

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
