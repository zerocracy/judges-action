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

require 'fbe/fb'
require 'fbe/octo'
require 'fbe/unmask_repos'
require 'fbe/regularly'

Fbe.regularly('quality', 'qos_interval', 'qos_days') do |f|
  # Workflow runs:
  total = 0
  success = 0
  duration = 0
  ttrs = []
  failed = {}
  Fbe.unmask_repos.each do |repo|
    Fbe.octo.repository_workflow_runs(repo, created: ">#{f.since.utc.iso8601[0..9]}")[:workflow_runs].each do |json|
      workflow_id = json[:workflow_id]
      run_duration = (Fbe.octo.workflow_run_usage(repo, json[:id])[:run_duration_ms] || 0) / 1000
      completed = json[:run_started_at] + run_duration
      if json[:conclusion] == 'failure' && failed[workflow_id].nil?
        failed[workflow_id] = completed
      elsif json[:conclusion] == 'success' && failed[workflow_id]
        ttrs << (completed - failed[workflow_id]).to_i
        failed.delete(workflow_id)
      end
      total += 1
      success += json[:conclusion] == 'success' ? 1 : 0
      duration += run_duration
    end
  end
  f.average_build_success_rate = total.zero? ? 0 : success.to_f / total
  f.average_build_duration = total.zero? ? 0 : duration.to_f / total
  f.average_build_mttr = ttrs.any? ? ttrs.sum / ttrs.size : 0

  # Release intervals:
  dates = []
  Fbe.unmask_repos.each do |repo|
    Fbe.octo.releases(repo).each do |json|
      break if json[:published_at] < f.since
      dates << json[:published_at]
    end
  end
  dates.sort!
  diffs = (1..dates.size - 1).map { |i| dates[i] - dates[i - 1] }
  f.average_release_interval = diffs.empty? ? 0 : diffs.inject(&:+) / diffs.size

  # Release hoc and commit size
  repo_releases = {}
  hocs = []
  commits = []
  Fbe.unmask_repos.each do |repo|
    Fbe.octo.releases(repo).each do |json|
      break if json[:published_at] < f.since
      (repo_releases[repo] ||= []) << json
    end
  end
  repo_releases.each do |repo, releases|
    releases.reverse.each_cons(2) do |first, last|
      Fbe.octo.compare(repo, first[:tag_name], last[:tag_name]).then do |json|
        hocs << json[:files].map { |file| file[:changes] }.sum
        commits << json[:total_commits]
      end
    end
  end
  f.average_release_hoc_size = hocs.empty? ? 0 : hocs.sum.to_f / hocs.size
  f.average_release_commits_size = commits.empty? ? 0 : commits.sum.to_f / commits.size

  # Issue and PR lifetimes:
  { issue: 'average_issue_lifetime', pr: 'average_pull_lifetime' }.each do |type, prop|
    ages = []
    Fbe.unmask_repos.each do |repo|
      q = "repo:#{repo} type:#{type} closed:>#{f.since.utc.iso8601[0..9]}"
      ages +=
        Fbe.octo.search_issues(q)[:items].map do |json|
          next if json[:closed_at].nil?
          next if json[:created_at].nil?
          json[:closed_at] - json[:created_at]
        end
    end
    ages.compact!
    f.send("#{prop}=", ages.empty? ? 0 : ages.inject(&:+).to_f / ages.size)
  end

  # Average issues
  issues = []
  Fbe.unmask_repos.each do |repo|
    (f.since.utc.to_date..Time.now.utc.to_date).each do |date|
      count = 0
      Fbe.octo.search_issues(
        "repo:#{repo} type:issue created:#{f.since.utc.to_date.iso8601[0..9]}..#{date.iso8601[0..9]}"
      )[:items].each do |item|
        count += 1 if item[:closed_at].nil? || item[:closed_at].utc.to_date >= date
      end
      issues << count
    end
  end
  f.average_backlog_size = issues.empty? ? 0 : issues.inject(&:+).to_f / issues.size

  # Rejection PR rate
  pulls = 0
  rejected = 0
  Fbe.unmask_repos.each do |repo|
    pulls += Fbe.octo.search_issues("repo:#{repo} type:pr closed:>#{f.since.utc.iso8601[0..9]}")[:total_count]
    rejected += Fbe.octo.search_issues(
      "repo:#{repo} type:pr is:unmerged closed:>#{f.since.utc.iso8601[0..9]}"
    )[:total_count]
  end
  f.average_pull_rejection_rate = pulls.zero? ? 0 : rejected.to_f / pulls

  # Average HOC and number of files changed in recent merged PRs
  hocs = []
  files = []
  Fbe.unmask_repos.each do |repo|
    Fbe.octo.search_issues(
      "repo:#{repo} type:pr is:merged closed:>#{f.since.utc.iso8601[0..9]}"
    )[:items].each do |json|
      Fbe.octo.pull_request(repo, json[:number]).then do |pull|
        hocs << (pull[:additions] + pull[:deletions])
        files << pull[:changed_files]
      end
    end
  end
  f.average_pull_hoc_size = hocs.empty? ? 0 : hocs.sum.to_f / hocs.size
  f.average_pull_files_size = files.empty? ? 0 : files.sum.to_f / files.size

  # Average review time, review comments, reviewers and reviews
  review_times = []
  review_comments = []
  reviewers = []
  reviews = []
  Fbe.unmask_repos.each do |repo|
    Fbe.octo.search_issues(
      "repo:#{repo} type:pr is:merged closed:>#{f.since.utc.iso8601[0..9]}"
    )[:items].each do |pr|
      pr_reviews = Fbe.octo.pull_request_reviews(repo, pr[:number])
      pr_review = pr_reviews.select { |r| r[:submitted_at] }.min_by { |r| r[:submitted_at] }
      review_times << (pr[:pull_request][:merged_at] - pr_review[:submitted_at]).to_i if pr_review
      review_comments << Fbe.octo.review_comments(repo, pr[:number]).size
      reviewers << pr_reviews.map { |r| r.dig(:user, :id) }.uniq.size
      reviews << pr_reviews.size
    end
  end
  f.average_review_time = review_times.empty? ? 0 : review_times.sum.to_f / review_times.size
  f.average_review_size = review_comments.empty? ? 0 : review_comments.sum.to_f / review_comments.size
  f.average_reviewers_per_pull = reviewers.empty? ? 0 : reviewers.sum.to_f / reviewers.size
  f.average_reviews_per_pull = reviews.empty? ? 0 : reviews.sum.to_f / reviews.size

  # Average triage time for issues
  triage_times = []
  Fbe.unmask_repos.each do |repo|
    Fbe.octo.search_issues("repo:#{repo} type:issue created:>#{f.since.utc.iso8601[0..9]}")[:items].each do |issue|
      ff = Fbe.fb.query(
        <<~QUERY
          (and
            (eq where 'github')
            (eq repository #{Fbe.octo.repo_id_by_name(repo)})
            (eq issue #{issue[:number]})
            (eq what 'label-was-attached')
            (exists when)
            (or
              (eq label 'bug')
              (eq label 'enhancement')
            )
          )
        QUERY
      ).each.min_by(&:when)
      triage_times << (ff.when - issue[:created_at]) if ff
    end
  end
  f.average_triage_time = triage_times.empty? ? 0 : triage_times.sum.to_f / triage_times.size
end
