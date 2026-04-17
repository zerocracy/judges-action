# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'

def some_review_time(fact)
  times = []
  sizes = []
  reviewers = []
  reviews = []
  Fbe.unmask_repos do |repo|
    Fbe.octo.search_issues(
      "repo:#{repo} type:pr is:merged closed:#{fact.since.utc.iso8601}..#{fact.when.utc.iso8601}"
    )[:items].each do |pr|
      all = Fbe.octo.pull_request_reviews(repo, pr[:number])
      first = all.select { |r| r[:submitted_at] }.min_by { |r| r[:submitted_at] }
      times << Integer(pr[:pull_request][:merged_at] - first[:submitted_at]) if first
      sizes << Fbe.octo.review_comments(repo, pr[:number]).size
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
