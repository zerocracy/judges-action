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
  Fbe.unmask_repos.each do |repo|
    Fbe.octo.repository_workflow_runs(repo, created: ">#{f.since.utc.iso8601[0..10]}")[:workflow_runs].each do |json|
      total += 1
      success += json[:conclusion] == 'success' ? 1 : 0
      duration += Fbe.octo.workflow_run_usage(repo, json[:id])[:run_duration_ms] / 1000
    end
  end
  f.average_build_success_rate = total.zero? ? 0 : success.to_f / total
  f.average_build_duration = total.zero? ? 0 : duration.to_f / total

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

  # Issue and PR lifetimes:
  { issue: 'average_issue_lifetime', pr: 'average_pull_lifetime' }.each do |type, prop|
    ages = []
    Fbe.unmask_repos.each do |repo|
      q = "repo:#{repo} type:#{type} closed:>#{f.since.utc.iso8601[0..10]}"
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
    Fbe.octo.repository(repo).then do |json|
      issues << json[:open_issues]
    end
  end
  f.average_backlog_size = issues.empty? ? 0 : issues.inject(&:+) / issues.size

  # Rejection PR rate
  pulls = 0
  rejected = 0
  Fbe.unmask_repos.each do |repo|
    pulls += Fbe.octo.search_issues("repo:#{repo} type:pr closed:>#{f.since.utc.iso8601[0..10]}")[:total_count]
    rejected += Fbe.octo.search_issues(
      "repo:#{repo} type:pr is:unmerged closed:>#{f.since.utc.iso8601[0..10]}"
    )[:total_count]
  end
  f.average_pull_rejection_rate = pulls.zero? ? 0 : rejected.to_f / pulls
end
