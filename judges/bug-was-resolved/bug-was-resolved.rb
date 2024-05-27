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

conclude do
  on '(and (eq what "label-was-attached")
    (exists when)
    (exists issue)
    (exists repository)
    (exists label)
    (or (eq label "bug") (eq label "enhancement") (eq label "question")))'
  on '(and (eq what "issue-was-closed")
    (exists who)
    (exists when)
    (eq issue {f0.issue})
    (eq repository {f0.repository}))'
  on '(and (eq what "issue-was-assigned")
    (exists when)
    (eq issue {f0.issue})
    (exists is_human)
    (eq repository {f0.repository})
    (exists who))'
  follow 'f1.when f2.who repository issue'
  draw do |n, attached, closed, assigned|
    n.seconds = closed.when - assigned.when
    repo = octo.repo_name_by_id(n.repository)
    "The bug/feature in the issue #{repo}##{n.issue} was resolved, " \
      "because it was closed by ##{closed.who} and earlier it was" \
      "assigned to ##{n.who}' and the label '##{attached.label}' was attached."
  end
end
