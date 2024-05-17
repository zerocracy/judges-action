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

once($fb).query("(and
  (eq kind 'bug was accepted')
  (exists github_issue)
  (exists github_repository)
  (exists github_reporter))").each do |f|
  n = $fb.insert
  n.kind = 'reward for good bug'
  n.github_issue = f.github_issue
  n.github_repository = f.github_repository
  n.payee = f.github_reporter
  n.award = 15
  n.reason = 'Thanks for reporting a new bug! You earn +15 points for this. \
    By reporting bugs, you help our project improve its quality.
    If you find anything else in the repository that doesn\'t look
    as good as you might expect, do not hesitate to report it.'
end
