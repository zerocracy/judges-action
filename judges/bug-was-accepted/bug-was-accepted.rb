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
  on "
  (and
    (eq what 'label-was-attached')
    (exists who)
    (exists issue)
    (exists repository)
    (join 'reporter<=who' (and
        (eq what 'issue-was-opened')
        (eq issue $issue)
        (eq repository $repository)))
    (exists reporter)
    (not (eq who reporter))
    (empty (and
      (eq what '#{$judge}')
      (eq issue $issue)
      (eq repository $repository)))
    (eq label 'bug'))"
  follow 'when who repository issue reporter'
  draw do |n, prev|
    "In the repository ##{n.repository}, the user ##{n.who} attached " \
      "the '##{prev.label}' label to the issue ##{n.issue} " \
      "reported by the user ##{n.reporter}; " \
      'this means that a bug was-accepted as valid, by the project team.'
  end
end
