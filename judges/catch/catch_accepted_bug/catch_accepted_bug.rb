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

fb.query("(and (eq what 'label-attached')
  (exists issue)
  (exists repository)
  (eq label '#{label}'))").each do |f1|
  $loog.debug("Label '#{f1.label}' was attached to issue ##{f1.issue}")
  once(fb).query("(and (eq what 'issue-opened')
    (exists who)
    (eq issue #{f1.issue})
    (eq repository #{f1.repository}))").each do |f2|
    fb.txn do |fbt|
      n = follow(fbt, f1, ['repository', 'issue'])
      n.what = 'bug-was-accepted'
      n.who = f2.who
      n.details =
        "In the repository ##{f1.repository}, the '#{label}' label was attached " \
        "to the issue ##{f1.issue}, which was submitted by the user ##{n.who}; " \
        'this means that a bug-was-accepted as valid, by the project team.'
    end
  end
end
