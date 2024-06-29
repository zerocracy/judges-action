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
require 'fbe/conclude'

Fbe.conclude do
  on "(and
    (eq what 'issue-was-closed')
    (exists who)
    (exists when)
    (exists issue)
    (exists repository)
    (exists assigner)
    (as seconds (minus when submitted_when))
    (as closer who) # who closed the bug
    (as who assigner) # who assigned the bug to the resolver
    (empty (and
      (eq what '#{$judge}')
      (eq issue $issue)
      (eq repository $repository))))"
  follow 'when repository issue label seconds closer who'
  draw do |n, _|
    "The pull request #{J.issue(n)} " \
      "created by @#{J.who(n)}' was merged, " \
      "after #{Time.seconds}" \
      "after #{n.comments} comments " \
      "#{n['reviewer'].nil? ? 'by no reviewers' : "by #{n['reviewer'].size} reviewers"}"
  end
end
