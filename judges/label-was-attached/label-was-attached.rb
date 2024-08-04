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
require 'fbe/iterate'
require 'fbe/if_absent'
require 'fbe/issue'

Fbe.iterate do
  as 'labels-were-scanned'
  by "(agg (and (eq repository $repository) (eq what 'issue-was-opened') (gt issue $before)) (min issue))"
  quota_aware
  repeats 20
  over do |repository, issue|
    Fbe.octo.issue_timeline(repository, issue).each do |te|
      Fbe.fb.query("(eq issue #{issue})").delete! if te[:status] == '404'
      next unless te[:event] == 'labeled'
      badge = te[:label][:name]
      next unless %w[bug enhancement question].include?(badge)
      nn =
        Fbe.if_absent do |n|
          n.where = 'github'
          n.repository = repository
          n.issue = issue
          n.label = te[:label][:name]
          n.what = $judge
        end
      next if nn.nil?
      nn.who = te[:actor][:id]
      nn.when = te[:created_at]
      nn.details =
        "The '##{nn.label}' label was attached by @#{te[:actor][:login]} " \
        "to the issue #{Fbe.issue(nn)}."
    end
    issue
  end
end
