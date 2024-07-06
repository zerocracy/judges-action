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
    (eq what 'bug-was-accepted')
    (exists where)
    (exists when)
    (gt when #{(Time.now - (J.pmp.hr.days_to_reward * 24 * 60 * 60)).utc.iso8601})
    (exists reporter)
    (exists issue)
    (exists repository)
    (exists who)
    (eq is_human 1)
    (empty (and
      (eq what '#{$judge}')
      (eq where $where)
      (eq issue $issue)
      (eq repository $repository))))"
  follow 'where repository issue'
  draw do |n, accepted|
    n.award = 15
    n.when = Time.now
    n.who = accepted.reporter
    n.why = "Bug #{J.issue(n)} was accepted"
    n.greeting =
      "Thanks for reporting a new bug! You've just earned #{J.award(n)} points for this. " \
      'By reporting bugs, you help our project improve its quality. ' \
      'If you find anything else in the repository that ' \
      '[doesn\'t look](https://www.yegor256.com/2018/02/06/where-to-find-more-bugs.html) ' \
      'as good as you might expect, ' \
      '[do not hesitate](https://www.yegor256.com/2014/04/13/bugs-are-welcome.html) to ' \
      '[report](https://www.yegor256.com/2018/04/24/right-way-to-report-bugs.html) ' \
      "it.#{J.balance(n.who)}"
    "It's time to reward #{J.who(n)} for the issue reported in " \
      "#{J.issue(n)}, the reward amount is #{J.award(n)}."
  end
end
