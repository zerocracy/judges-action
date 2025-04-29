# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'

# Average review time, review comments, reviewers and reviews
#
# This function is called from the "quality-of-service.rb".
#
# @param [Factbase::Fact] fact The fact just under processing
# @return [Hash] Map with keys as fact attributes and values as integers
def average_review_time(fact)
  review_times = []
  review_comments = []
  reviewers = []
  reviews = []
  Fbe.unmask_repos.each do |repo|
    Fbe.octo.search_issues(
      "repo:#{repo} type:pr is:merged closed:>#{fact.since.utc.iso8601[0..9]}"
    )[:items].each do |pr|
      pr_reviews = Fbe.octo.pull_request_reviews(repo, pr[:number])
      pr_review = pr_reviews.select { |r| r[:submitted_at] }.min_by { |r| r[:submitted_at] }
      review_times << (pr[:pull_request][:merged_at] - pr_review[:submitted_at]).to_i if pr_review
      review_comments << Fbe.octo.review_comments(repo, pr[:number]).size
      reviewers << pr_reviews.map { |r| r.dig(:user, :id) }.uniq.size
      reviews << pr_reviews.size
    end
  end
  {
    average_review_time: review_times.empty? ? 0 : review_times.sum.to_f / review_times.size,
    average_review_size: review_comments.empty? ? 0 : review_comments.sum.to_f / review_comments.size,
    average_reviewers_per_pull: reviewers.empty? ? 0 : reviewers.sum.to_f / reviewers.size,
    average_reviews_per_pull: reviews.empty? ? 0 : reviews.sum.to_f / reviews.size
  }
end

def average_review_time_props
  %w[average_review_time average_review_size average_reviewers_per_pull average_reviews_per_pull]
end
