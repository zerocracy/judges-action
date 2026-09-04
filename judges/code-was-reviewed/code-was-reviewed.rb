# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'faraday'
require 'fbe/consider'
require 'fbe/issue'
require 'fbe/octo'
require 'fbe/who'
require 'octokit'
require_relative '../../lib/issue_was_lost'

Fbe.consider(
  "(and
    (or
      (eq what 'pull-was-merged')
      (eq what 'pull-was-closed'))
    (exists repository)
    (exists issue)
    (absent reviews)
    (absent stale)
    (absent tombstone)
    (absent done)
    (eq where 'github')
    (unique where repository issue)
    (empty
      (and
        (eq issue $issue)
        (eq repository $repository)
        (eq where 'github')
        (eq what '#{$judge}'))))"
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
  pr =
    begin
      Fbe.octo.pull_request(repo, f.issue)
    rescue Octokit::NotFound, Octokit::Deprecated => e
      $loog.info("The pull request ##{f.issue} doesn't exist in #{repo}: #{e.message}")
      Jp.issue_was_lost(f.where, f.repository, f.issue)
      next
    rescue Octokit::Forbidden => e
      $loog.warn(
        "[#{$judge}] Access forbidden to pull ##{f.issue} in #{repo} " \
        "(transient, will retry next cycle): #{e.class}: #{e.message}"
      )
      next
    rescue Octokit::Unauthorized => e
      $loog.error("[#{$judge}] Not authorized to fetch pull ##{f.issue} in #{repo}: #{e.class}: #{e.message}")
      next
    rescue Octokit::TooManyRequests, Octokit::ServerError,
      Faraday::TimeoutError, Faraday::ConnectionFailed => e
      $loog.warn(
        "[#{$judge}] Transient error fetching pull ##{f.issue} in #{repo} " \
        "(will retry next cycle): #{e.class}: #{e.message}"
      )
      next
    end
  reviews =
    begin
      Fbe.octo.pull_request_reviews(repo, f.issue)
    rescue Octokit::NotFound, Octokit::Deprecated => e
      $loog.info("The pull request ##{f.issue} doesn't exist in #{repo}: #{e.message}")
      Jp.issue_was_lost(f.where, f.repository, f.issue)
      next
    rescue Octokit::Forbidden => e
      $loog.warn(
        "[#{$judge}] Access forbidden to reviews for pull ##{f.issue} in #{repo} " \
        "(transient, will retry next cycle): #{e.class}: #{e.message}"
      )
      next
    rescue Octokit::Unauthorized => e
      $loog.error(
        "[#{$judge}] Not authorized to fetch reviews for pull ##{f.issue} in #{repo}: #{e.class}: #{e.message}"
      )
      next
    rescue Octokit::TooManyRequests, Octokit::ServerError,
      Faraday::TimeoutError, Faraday::ConnectionFailed => e
      $loog.warn(
        "[#{$judge}] Transient error fetching reviews for pull ##{f.issue} in #{repo} " \
        "(will retry next cycle): #{e.class}: #{e.message}"
      )
      next
    end
  f.reviews = reviews.count { |review| review.dig(:user, :id) != pr.dig(:user, :id) }
  count = nil
  reviews.each do |review|
    reviewer = review.dig(:user, :id)
    next if reviewer.nil?
    next if reviewer == pr.dig(:user, :id)
    Fbe.fb.txn do |fbt|
      n =
        Fbe.if_absent(fb: fbt) do |nn|
          nn.issue = f.issue
          nn.who = review.dig(:user, :id)
          nn.what = $judge
          nn.repository = f.repository
          nn.where = f.where
        end
      next if n.nil?
      n.when = review[:submitted_at]
      n.hoc = (pr[:additions] || 0) + (pr[:deletions] || 0)
      n.author = pr.dig(:user, :id)
      count ||=
        begin
          Fbe.octo.issue_comments(repo, f.issue).count
        rescue Octokit::NotFound, Octokit::Deprecated => e
          $loog.info("Issue comments not found for #{repo}##{f.issue}: #{e.message}")
          0
        rescue Octokit::Forbidden => e
          $loog.warn(
            "[#{$judge}] Access forbidden to issue comments for #{repo}##{f.issue} " \
            "(transient, will retry next cycle): #{e.class}: #{e.message}"
          )
          next
        rescue Octokit::Unauthorized => e
          $loog.error(
            "[#{$judge}] Not authorized to fetch issue comments for #{repo}##{f.issue}: #{e.class}: #{e.message}"
          )
          next
        rescue Octokit::TooManyRequests, Octokit::ServerError,
          Faraday::TimeoutError, Faraday::ConnectionFailed => e
          $loog.warn(
            "[#{$judge}] Transient error fetching issue comments for #{repo}##{f.issue} " \
            "(will retry next cycle): #{e.class}: #{e.message}"
          )
          next
        end
      n.comments = count
      n.review_comments =
        begin
          Fbe.octo.pull_request_review_comments(repo, f.issue, review[:id]).count
        rescue Octokit::NotFound, Octokit::Deprecated => e
          $loog.info("Review comments not found for #{repo}##{f.issue}: #{e.message}")
          0
        rescue Octokit::Forbidden => e
          $loog.warn(
            "[#{$judge}] Access forbidden to review comments for #{repo}##{f.issue} " \
            "(transient, will retry next cycle): #{e.class}: #{e.message}"
          )
          next
        rescue Octokit::Unauthorized => e
          $loog.error(
            "[#{$judge}] Not authorized to fetch review comments for #{repo}##{f.issue}: #{e.class}: #{e.message}"
          )
          next
        rescue Octokit::TooManyRequests, Octokit::ServerError,
          Faraday::TimeoutError, Faraday::ConnectionFailed => e
          $loog.warn(
            "[#{$judge}] Transient error fetching review comments for #{repo}##{f.issue} " \
            "(will retry next cycle): #{e.class}: #{e.message}"
          )
          next
        end
      n.seconds = Integer(review[:submitted_at] - pr[:created_at])
      n.details =
        "The pull request #{Fbe.issue(n)} with #{n.hoc} HoC " \
        "created by #{Fbe.who(n, :author)} was reviewed by #{Fbe.who(n)} " \
        "after #{n.seconds / 3600}h#{(n.seconds % 3600) / 60}m and #{n.review_comments} comments."
      $loog.info(
        [
          "The pull #{Fbe.issue(n)} was reviewed by #{Fbe.who(n)} #{n.when.ago} ago:",
          "#{n.review_comments} review comments, #{n.seconds} seconds, #{n.comments} comments"
        ].join(' ')
      )
    end
  end
end

Fbe.octo.print_trace!
