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

# Take the latest GitHub issue number that we checked for labels.
def latest(repo)
  f = fb.query("(and (eq what '#{$judge}') (eq repository #{repo}) (exists issue) (eq _time (max _time)))").each.to_a[0]
  issue = f.issue unless f.nil?
  issue = 0 if f.nil?
  issue
end

# Take the maximum GitHub issue number for this repo.
def max(repo)
  f = fb.query("(eq issue (agg (and (eq what 'issue-was-opened') (eq repository #{repo})) (max issue)))").each.to_a[0]
  return nil? if f.nil?
  f.issue
end

fb.query('(unique repository)').each.to_a.map(&:repository).each do |repo|
  latest = latest(repo)
  unless latest.zero?
    max = max(repo)
    latest = 0 if max.nil? || latest == max
  end
  conclude do
    quota_aware
    on "(eq issue
      (agg
        (and
          (eq what 'issue-was-opened')
          (eq repository #{repo})
          (gt issue #{latest}))
        (min issue)))"
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
              "to the issue #{repo}##{n.issue} at #{n.when.utc.iso8601}; " \
              'this may trigger future judges.'
      end
    end
  end
end
