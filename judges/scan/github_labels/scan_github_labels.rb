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

require_relative '../../../lib/octokit'

catch :stop do
  repositories do |repo|
    octokit.search_issues("repo:#{repo} label:bug,enhancement,question")[:items].each do |e|
      e[:labels].each do |label|
        n = if_absent($fb) do |f|
          f.kind = 'GitHub event'
          f.github_action = 'label-attached'
          f.github_repository = repo
          f.github_issue = e[:number]
          f.github_label = label[:name]
        end
        next if n.nil?

        $loog.info("Detected new label '##{label[:name]}' at #{repo}##{e[:number]}")
        n.time = Time.now
        left = octokit.rate_limit.remaining
        if left < 5
          $loog.info("To much GitHub API quota consumed already (remaining=#{left}), stopping")
          throw :stop
        end
      end
    end
  end
end
