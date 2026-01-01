# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

# Judge that monitors pull-was-merged or pull-was-closed facts with exists repository
# and issue properties and create missing code-was-reviewed fact.

require 'fbe/octo'
require 'fbe/consider'
require 'fbe/issue'
require 'fbe/who'
require_relative '../../lib/issue_was_lost'

Fbe.consider(
  "(and
    (or
      (eq what 'pull-was-merged')
      (eq what 'pull-was-closed'))
    (exists repository)
    (exists issue)
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
  repo = Fbe.octo.repo_name_by_id(f.repository)
  pr = Fbe.octo.pull_request(repo, f.issue)
  reviews =
    begin
      Fbe.octo.pull_request_reviews(repo, f.issue)
    rescue Octokit::NotFound
      $loog.info("The pull request ##{f.issue} doesn't exist in #{repo}")
      Jp.issue_was_lost(f.where, f.repository, f.issue)
      next
    end
  reviews.each do |review|
    next if review.dig(:user, :id) == pr.dig(:user, :id)
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
      n.hoc = pr[:additions] + pr[:deletions]
      n.author = pr.dig(:user, :id)
      n.comments = Fbe.octo.issue_comments(repo, f.issue).count
      n.review_comments = Fbe.octo.pull_request_review_comments(repo, f.issue, review[:id]).count
      n.seconds = (review[:submitted_at] - pr[:created_at]).to_i
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
