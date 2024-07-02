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

require 'fbe/conclude'

Fbe.conclude do
  on "(and
    (eq what 'issue-was-closed')
    (exists who)
    (exists when)
    (exists issue)
    (exists repository)
    (join 'label' (and
      (eq what 'label-was-attached')
      (eq issue $issue)
      (eq repository $repository)
      (or (eq label 'bug') (eq label 'enhancement') (eq label 'question'))))
    (exists label)
    (join 'assigned_when<=when,assigner<=who' (and
        (eq what 'issue-was-assigned')
        (eq issue $issue)
        (eq repository $repository)))
    (exists assigner)
    (as seconds (to_int (minus when assigned_when)))
    (as closer who) # who closed the bug
    (as who assigner) # who assigned the bug to the resolver
    (empty (and
      (eq what '#{$judge}')
      (eq issue $issue)
      (eq repository $repository))))"
  follow 'when repository issue label seconds closer who'
  draw do |n, _|
    "The bug/feature in the issue #{J.issue(n)} was resolved, " \
      "aftet #{J.sec(n)} of waiting, " \
      "because it was closed by #{J.who(n, :closer)} and earlier it was" \
      "assigned to #{J.who(n)} and the label '##{n.label}' was attached."
  end
end
