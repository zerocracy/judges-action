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

return unless Fbe.fb.query(
  "(and
    (eq what '#{$judge}')
    (gt when (minus (to_time (env 'TODAY' '#{Time.now}')) '7 days')))"
).each.to_a.empty?

f = Fbe.fb.insert
f.what = $judge
f.when = Time.now

def lifetime(days, type)
  ages = []
  Fbe.unmask_repos.each do |repo|
    q = "repo:#{repo} type:#{type} closed:>#{(Time.now - (days * 24 * 60 * 60)).utc.iso8601[0..10]}"
    ages += Fbe.octo.search_issues(q)[:items].map do |json|
      next if json[:closed_at].nil?
      next if json[:created_at].nil?
      json[:closed_at] - json[:created_at]
    end
  end
  ages.compact!
  ages.empty? ? 0 : ages.inject(&:+) / ages.size
end

f.average_issue_lifetime = lifetime(28, 'issue')
f.average_pull_lifetime = lifetime(28, 'pr')
