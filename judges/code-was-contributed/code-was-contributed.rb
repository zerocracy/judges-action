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
    (eq what 'pull-was-merged')
    (exists who)
    (exists when)
    (exists issue)
    (exists repository)
    (join 'submitted_when<=when,submitter<=who' (and
        (eq what 'pull-was-opened')
        (eq issue $issue)
        (eq repository $repository)))
    (exists submitter)
    (as seconds (minus when submitted_when))
    (as merger who) # who merged the pull request
    (as who submitter) # who submitted the pull request
    (empty (and
      (eq what '#{$judge}')
      (eq issue $issue)
      (eq repository $repository))))"
  follow 'when repository issue seconds who merger'
  draw do |n, _|
    "The pull request #{J.issue(n)} " \
      "created by #{J.who(n)} was merged by #{J.who(n, :merger)} " \
      "after #{J.sec(n)} of being in review"
  end
end
