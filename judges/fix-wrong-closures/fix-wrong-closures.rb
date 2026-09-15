# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/issue'
require 'fbe/iterate'
require 'fbe/octo'
require 'fbe/overwrite'
require 'octokit'
require_relative '../../lib/issue_was_lost'

Fbe.iterate do
  as 'closures_were_checked'
  sort_by 'issue'
  by "
    (and
      (eq repository $repository)
      (gt issue $before)
      (eq what 'pull-was-closed')
      (eq where 'github')
      (unique issue)
      (absent stale)
      (absent tombstone)
      (absent done))"
  repeats 50
  over do |repository, issue|
    repo =
      begin
        Fbe.octo.repo_name_by_id(repository)
      rescue Octokit::NotFound, Octokit::Deprecated => e
        $loog.info("Repository ##{repository} not found: #{e.message}")
        next issue
      rescue Octokit::Forbidden => e
        $loog.warn(
          "[#{$judge}] Access forbidden to repository ##{repository} " \
          "(transient, will retry next cycle): #{e.class}: #{e.message}"
        )
        next issue
      end
    json =
      begin
        Fbe.octo.pull_request(repo, issue)
      rescue Octokit::NotFound, Octokit::Deprecated => e
        $loog.info("The pull ##{issue} doesn't exist in #{repo}: #{e.message}")
        Jp.issue_was_lost('github', repository, issue)
        next issue
      rescue Octokit::Forbidden => e
        $loog.warn(
          "[#{$judge}] Access forbidden to pull ##{issue} in #{repo} " \
          "(transient, will retry next cycle): #{e.class}: #{e.message}"
        )
        next issue
      rescue Octokit::TooManyRequests, Octokit::Unauthorized, Octokit::ServerError,
        Net::OpenTimeout, Net::ReadTimeout, SocketError,
        Errno::ECONNRESET, Errno::ETIMEDOUT => e
        $loog.warn(
          "[#{$judge}] Transient error fetching pull ##{issue} in #{repo} " \
          "(will retry next cycle): #{e.class}: #{e.message}"
        )
        next issue
      end
    next issue if json[:merged_at].nil? && json[:state] != 'open'
    closures = Fbe.fb.query(
      "(and
        (eq where 'github')
        (eq repository #{repository})
        (eq issue #{issue})
        (eq what 'pull-was-closed'))"
    )
    merges = Fbe.fb.query(
      "(and
        (eq where 'github')
        (eq repository #{repository})
        (eq issue #{issue})
        (eq what 'pull-was-merged'))"
    )
    if json[:merged_at] && merges.each.none?
      closures.each.to_a.each do |f|
        Fbe.overwrite(f, { 'what' => 'pull-was-merged', 'when' => json[:merged_at] })
      end
      $loog.info("The closure of #{repo}##{issue} is wrong, it was merged at #{json[:merged_at]}, converted")
      next issue
    end
    closures.delete!
    $loog.info(
      "The closure of #{repo}##{issue} is wrong, it is " \
      "#{json[:merged_at].nil? ? 'open' : 'merged'} now, forgotten"
    )
    issue
  end
end

Fbe.octo.print_trace!
