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
require 'fbe/iterate'
require 'fbe/if_absent'
require 'fbe/who'
require 'fbe/issue'

Fbe.iterate do
  as 'min-issue-was-found'
  by "(agg (and (eq where 'github') (eq repository $repository) (eq what 'issue-was-opened')) (min issue))"
  quota_aware
  over do |repository, issue|
    repo = Fbe.octo.repo_name_by_id(repository)
    begin
      after = Fbe.octo.issue(repo, issue)[:created_at]
    rescue Octokit::NotFound
      next 0
    end
    Fbe.octo.search_issues("repo:#{repo} type:issue created:<=#{after.iso8601[0..9]}")[:items].each do |json|
      f =
        Fbe.if_absent do |ff|
          ff.where = 'github'
          ff.what = 'issue-was-opened'
          ff.repository = repository
          ff.issue = json[:number]
        end
      next if f.nil?
      f.when = json[:created_at]
      f.who = json.dig(:user, :id)
      f.details = "The issue #{Fbe.issue(f)} has been opened by #{Fbe.who(f)}."
    end
    issue
  end
end
