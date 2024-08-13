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

Fbe.regularly('scope', 'qod_interval', 'qod_days') do |f|
  # Number of commits pushed and their hits-of-code:
  commits = 0
  hoc = 0
  Fbe.unmask_repos.each do |repo|
    next if Fbe.octo.repository(repo)[:size].zero?

    Fbe.octo.commits_since(repo, f.since).each do |json|
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
    Fbe.octo.list_issues(repo, since: ">#{f.since.utc.iso8601[0..9]}").each do |json|
      issues += 1
      pulls += 1 unless json[:pull_request].nil?
    end
  end
  f.total_issues_created = issues
  f.total_pulls_submitted = pulls
end
