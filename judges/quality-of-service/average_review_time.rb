# frozen_string_literal: true

# MIT License
#
# Copyright (c) 2024 Zerocracy
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

require 'fbe/octo'
require 'fbe/unmask_repos'

# Average review time, review comments, reviewers and reviews
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
