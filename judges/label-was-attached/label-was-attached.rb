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

# Taking the latest GitHub issue number that we checked for labels
latest = fb.query("(and (eq what '#{$judge}') (exists issue) (max _time))").each.to_a[0]
latest = latest.issue unless latest.nil?
latest = 0 if latest.nil?

conclude do
  quota_aware
  on "(and (eq what 'issue-was-opened')
    (eq issue (agg (gt issue #{latest}) (min issue))))"
  follow 'repository issue'
  threshold $options.max_labels || 16
  maybe do |n, _opened|
    octo.issue_timeline(n.repository, n.issue).each do |te|
      next unless te[:event] == 'labeled'
      badge = te[:label][:name]
      next unless %w[bug enhancement question].include?(badge)
      n.label = badge
      n.who = te[:actor][:id]
      n.when = te[:created_at]
      repo = octo.repo_name_by_id(n.repository)
      break "The '##{n.label}' label was attached by @#{te[:actor][:login]} " \
            "to the issue #{repo}##{n.issue} at #{n.when}, " \
            '; which may trigger future judges.'
    end
  end
end
