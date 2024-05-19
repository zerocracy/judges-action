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

label = 'bug'

fb.query("(and (eq kind 'github-event')
  (eq action 'label-attached')
  (exists issue)
  (exists repository)
  (eq label '#{label}'))").each do |f1|
  issue = f1.issue
  repo = f1.repository
  once(fb).query("(and (eq kind 'github-event')
    (eq action 'issue-opened')
    (exists actor)
    (eq issue #{issue})
    (eq repository '#{repo}'))").each do |f2|
    fb.txn do |fbt|
      n = fbt.insert
      n.kind = 'bug-was-accepted'
      author = f2.actor
      n.reporter = author
      n.repository = repo
      n.issue = issue
      n.details =
        "In the #{repo} repository, the '#{label}' label was attached " \
        "to the issue ##{issue}, which was submitted by @#{author}; " \
        'this means that a bug-was-accepted as valid, by the project team.'
    end
  end
end
