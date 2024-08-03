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

pmp = Fbe.fb.query('(and (eq what "pmp") (eq area "scope") (exists qod_days))').each.to_a.first
$DAYS = pmp.nil? ? 28 : pmp.qod_days
$SINCE = Time.now - ($DAYS * 24 * 60 * 60)
interval = pmp.nil? ? 7 : pmp.qod_interval

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
f.since = $SINCE

# Number of commits pushed and their hits-of-code:
commits = 0
hoc = 0
Fbe.unmask_repos.each do |repo|
  Fbe.octo.commits_since(repo, $SINCE).each do |json|
    commits += 1
    hoc += Fbe.octo.commit(repo, json[:sha])[:stats][:total]
  end
end
f.total_commits_pushed = commits
f.total_hoc_committed = hoc

# Number of issues and pull requests created:
issues = 0
pulls = 0
Fbe.unmask_repos.each do |repo|
  Fbe.octo.list_issues(repo, since: ">#{$SINCE.utc.iso8601[0..10]}").each do |json|
    issues += 1
    pulls += 1 unless json[:pull_request].nil?
  end
end
f.total_issues_created = issues
f.total_pulls_submitted = pulls
