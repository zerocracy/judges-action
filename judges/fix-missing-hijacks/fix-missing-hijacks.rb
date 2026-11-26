# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/consider'
require 'fbe/github_graph'
require 'fbe/issue'
require 'fbe/octo'
require 'octokit'
require_relative '../../lib/closing_issues'
require_relative '../../lib/issue_was_lost'

Fbe.consider(
  "(and
    (absent hijacks)
    (eq what 'pull-was-merged')
    (exists issue)
    (exists repository)
    (absent stale)
    (absent tombstone)
    (eq where 'github'))"
) do |f|
  repo =
    begin
      Fbe.octo.repo_name_by_id(f.repository)
    rescue Octokit::NotFound, Octokit::Deprecated
      f.stale = 'repository'
      next
    rescue Octokit::Forbidden, Octokit::Unauthorized, Octokit::TooManyRequests, Octokit::ServerError,
      Faraday::TimeoutError, Faraday::ConnectionFailed => e
      $loog.warn("Could not resolve repository #{f.repository}, will retry: #{e.message}")
      next
    end
  json =
    begin
      Fbe.octo.pull_request(repo, f.issue)
    rescue Octokit::NotFound, Octokit::Deprecated => e
      $loog.info("#{Fbe.issue(f)} doesn't exist in #{repo}: #{e.message}")
      Jp.issue_was_lost(f.where, f.repository, f.issue)
      next
    rescue Octokit::Forbidden => e
      $loog.warn(
        "[#{$judge}] Access forbidden to #{Fbe.issue(f)} in #{repo} " \
        "(transient, will retry next cycle): #{e.class}: #{e.message}"
      )
      next
    rescue Octokit::Unauthorized, Octokit::TooManyRequests, Octokit::ServerError,
      Faraday::TimeoutError, Faraday::ConnectionFailed => e
      $loog.warn("Could not read #{repo}##{f.issue}, will retry: #{e.class}: #{e.message}")
      next
    end
  closing = Jp.closing_issues(repo, f.issue)
  if closing.nil?
    $loog.warn(
      "[#{$judge}] The closing issues of #{Fbe.issue(f)} are unknown " \
      '(transient, will retry next cycle)'
    )
    next
  end
  Jp.fill_hijacks(f, closing, json.dig(:user, :id))
end

Fbe.octo.print_trace!
