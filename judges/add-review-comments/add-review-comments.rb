# frozen_string_literal: true

require 'fbe/consider'
require 'fbe/octo'
# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'octokit'
require_relative '../../lib/issue_was_lost'

Fbe.consider(
  '(and
    (or (eq what "pull-was-reviewed") (eq what "pull-was-merged"))
    (absent review_comments)
    (absent stale)
    (absent tombstone)
    (absent done)
    (exists issue)
    (exists repository)
    (eq where "github"))'
) do |f|
  repo =
    begin
      Fbe.octo.repo_name_by_id(f.repository)
    rescue Octokit::NotFound, Octokit::Deprecated => e
      $loog.info("Failed to find repository #{f.repository}: #{e.message}")
      f.stale = 'repository'
      next
    rescue Octokit::Forbidden => e
      $loog.warn(
        "[#{$judge}] Access forbidden to repository #{f.repository} " \
        "(transient, will retry next cycle): #{e.class}: #{e.message}"
      )
      next
    end
  json =
    begin
      Fbe.octo.pull_request(repo, f.issue)
    rescue Octokit::NotFound, Octokit::Deprecated => e
      $loog.info("Failed to find issue ##{f.issue} in #{repo}: #{e.message}")
      Jp.issue_was_lost(f.where, f.repository, f.issue)
      next
    rescue Octokit::Forbidden => e
      $loog.warn(
        "[#{$judge}] Access forbidden to issue ##{f.issue} in #{repo} " \
        "(transient, will retry next cycle): #{e.class}: #{e.message}"
      )
      next
    end
  c = json[:review_comments]
  f.review_comments = c
  $loog.info("Found #{c} review comments in #{repo}##{f.issue} (what: #{f.what})")
end

Fbe.octo.print_trace!
