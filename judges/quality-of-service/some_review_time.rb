# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'

# Some review time, review comments, reviewers and reviews
#
# This function is called from the "quality-of-service.rb".
#
# @param [Factbase::Fact] fact The fact just under processing
# @return [Hash] Map with keys as fact attributes and values as integers
def some_review_time(fact)
  review_times = []
  review_comments = []
  reviewers = []
  reviews = []
  Fbe.unmask_repos do |repo|
    Fbe.octo.search_issues(
      "repo:#{repo} type:pr is:merged closed:#{fact.since.utc.iso8601}..#{fact.when.utc.iso8601}"
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
    some_review_time: review_times,
    some_review_size: review_comments,
    some_reviewers_per_pull: reviewers,
    some_reviews_per_pull: reviews
  }
end
