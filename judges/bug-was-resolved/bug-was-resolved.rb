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
        (eq repository $repository)
        (eq is_human 1)))
    (exists assigner)
    (empty (and
      (eq what '#{$judge}')
      (eq issue $issue)
      (eq repository $repository))))"
  follow 'when repository issue label'
  draw do |n, prev|
    n.seconds = prev.when - prev.assigned_when
    n.closer = prev.who
    n.who = prev.assigner
    "The bug/feature in the issue #{octo.repo_name_by_id(n.repository)}##{n.issue} was resolved, " \
      "because it was closed by @#{octo.user_name_by_id(n.closer)} and earlier it was" \
      "assigned to @#{octo.user_name_by_id(n.who)}' and the label '##{n.label}' was attached."
  end
end
