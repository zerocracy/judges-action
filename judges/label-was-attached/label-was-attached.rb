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
  f = fb.query("(and (eq seen '#{$judge}') (eq repository #{repo}) (exists issue) (eq _time (max _time)))").each.to_a[0]
  issue = f.issue unless f.nil?
  if f.nil?
    issue = 0
    $loog.debug("We never searched for labels in the ##{repo} repo")
  else
    $loog.debug("We most recently checked issue ##{issue} in ##{repo} repo, for labels")
  end
  issue
end

# Take the maximum GitHub issue number for this repo.
def max(repo)
  f = fb.query("(eq issue (agg (and (eq what 'issue-was-opened') (eq repository #{repo})) (max issue)))").each.to_a[0]
  if f.nil?
    $loog.debug("No issues have been opened in the ##{repo} repo")
    return nil?
  end
  $loog.debug("The issues #{f.issue} is the largest in the ##{repo} repo")
  f.issue
end

fb.query('(unique repository)').each.to_a.map(&:repository).each do |repo|
  latest = latest(repo)
  unless latest.zero?
    max = max(repo)
    if max.nil? || latest == max
      latest = 0
      $loog.debug("It's time to start from the first issue, since we reached the max issue ##{max}")
    else
      $loog.debug("The latest was the issue ##{latest}, while the max is ##{max}")
    end
  end
  conclude do
    quota_aware
    on "(eq issue
      (agg
        (and
          (not (eq seen '#{$judge}'))
          (eq what 'issue-was-opened')
          (eq repository #{repo})
          (gt issue #{latest}))
        (min issue)))"
    threshold $options.max_labels || 16
    look do |f, _|
      octo.issue_timeline(f.repository, f.issue).each do |te|
        next unless te[:event] == 'labeled'
        badge = te[:label][:name]
        next unless %w[bug enhancement question].include?(badge)
        if_absent(fb) do |n|
          n.repository = f.repository
          n.issue = f.issue
          n.label = te[:label][:name]
          n.who = te[:actor][:id]
          n.when = te[:created_at]
          n.what = $judge
          n.details =
            "The '##{n.label}' label was attached by @#{te[:actor][:login]} " \
            "to the issue #{octo.repo_name_by_id(n.repository)}##{n.issue} " \
            "at #{n.when.utc.iso8601}; this may trigger future judges."
        end
      end
      f.seen = $judge
    end
  end
end
