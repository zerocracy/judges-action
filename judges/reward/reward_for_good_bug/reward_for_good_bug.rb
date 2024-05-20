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

once(fb).query("(and
  (eq what 'bug-was-accepted')
  (exists issue)
  (exists repository)
  (exists who))").each do |f|
  $loog.debug("Bug was accepted in the issue ##{f.issue}")
  fb.txn do |fbt|
    n = follow(fbt, f, %w[repository issue who])
    award = 15
    n.reason =
      "@#{n.who} thanks for reporting a new bug! You've earned #{award} points for this. " \
      'By reporting bugs, you help our project improve its quality. ' \
      'If you find anything else in the repository that doesn\'t look ' \
      'as good as you might expect, do not hesitate to report it.'
    n.award = award
    n.what = 'reward-for-good-bug'
  end
end
