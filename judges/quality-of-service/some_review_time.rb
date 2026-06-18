# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'
require 'octokit'
require_relative '../../lib/qos_search'

def some_review_time(fact)
  times = []
  sizes = []
  reviewers = []
  reviews = []
  Fbe.unmask_repos do |repo|
    return {} if Fbe.octo.off_quota?
    found = Jp.qosearch("repo:#{repo} type:pr is:merged closed:#{fact.since.utc.iso8601}..#{fact.when.utc.iso8601}")
    return {} if found.nil?
    found[:items].each do |pr|
      all, csize =
        begin
          [Fbe.octo.pull_request_reviews(repo, pr[:number]), Fbe.octo.review_comments(repo, pr[:number]).size]
        rescue Octokit::NotFound, Octokit::Deprecated => e
          $loog.info("The pull ##{pr[:number]} doesn't exist in #{repo}: #{e.message}")
          next
        rescue Octokit::Forbidden => e
          $loog.warn(
            "[#{$judge}] Access forbidden to pull ##{pr[:number]} in #{repo} " \
            "(transient, will retry next cycle): #{e.class}: #{e.message}"
          )
          next
        end
      first = all.select { |r| r[:submitted_at] }.min_by { |r| r[:submitted_at] }
      times << Integer(pr[:pull_request][:merged_at] - first[:submitted_at]) if first
      sizes << csize
      users = all.map { |r| r.dig(:user, :id) }
      users.uniq!
      reviewers << users.size
      reviews << all.size
    end
  end
  {
    some_review_time: times,
    some_review_size: sizes,
    some_reviewers_per_pull: reviewers,
    some_reviews_per_pull: reviews
  }
end
