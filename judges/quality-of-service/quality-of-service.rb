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

pmp = Fbe.fb.query('(and (eq what "pmp") (eq area "quality") (exists qos_days))').each.to_a.first
$DAYS = pmp.nil? ? 28 : pmp.qos_days
$SINCE = Time.now - ($DAYS * 24 * 60 * 60)
interval = pmp.nil? ? 7 : pmp.qos_interval

unless Fbe.fb.query(
  "(and
    (eq what '#{$judge}')
    (gt when (minus (to_time (env 'TODAY' '#{Time.now.utc.iso8601}')) '#{interval} days')))"
).each.to_a.empty?
  $loog.debug("#{$judge} statistics have recently been collected, skipping now")
  return
end

f = Fbe.fb.insert
f.what = $judge
f.when = Time.now

# Workflow runs:
total = 0
success = 0
Fbe.unmask_repos.each do |repo|
  Fbe.octo.repository_workflow_runs(repo, created: ">#{$SINCE.utc.iso8601[0..10]}")[:workflow_runs].each do |json|
    total += 1
    success += json[:conclusion] == 'success' ? 1 : 0
  end
end
f.average_build_success_rate = total.zero? ? 0 : success.to_f / total

# Release intervals:
dates = []
Fbe.unmask_repos.each do |repo|
  Fbe.octo.releases(repo).each do |json|
    break if json[:published_at] < $SINCE
    dates << json[:published_at]
  end
end
dates.sort!
diffs = (1..dates.size - 1).map { |i| dates[i] - dates[i - 1] }
f.average_release_interval = diffs.empty? ? 0 : diffs.inject(&:+) / diffs.size

# Issue and PR lifetimes:
def lifetime(type)
  ages = []
  Fbe.unmask_repos.each do |repo|
    q = "repo:#{repo} type:#{type} closed:>#{$SINCE.utc.iso8601[0..10]}"
    ages +=
      Fbe.octo.search_issues(q)[:items].map do |json|
        next if json[:closed_at].nil?
        next if json[:created_at].nil?
        json[:closed_at] - json[:created_at]
      end
  end
  ages.compact!
  ages.empty? ? 0 : ages.inject(&:+).to_f / ages.size
end
f.average_issue_lifetime = lifetime('issue')
f.average_pull_lifetime = lifetime('pr')

# Average stars and forks for repos
stars = []
forks = []
Fbe.unmask_repos.each do |repo|
  Fbe.octo.repository(repo).then do |json|
    stars << json[:stargazers_count]
    forks << json[:forks]
  end
end
f.average_stars = stars.empty? ? 0 : stars.inject(&:+) / stars.size
f.average_forks = forks.empty? ? 0 : forks.inject(&:+) / forks.size

# Average issues
issues = []
Fbe.unmask_repos.each do |repo|
  Fbe.octo.repository(repo).then do |json|
    issues << json[:open_issues]
  end
end
f.average_backlog_size = issues.empty? ? 0 : issues.inject(&:+) / issues.size
