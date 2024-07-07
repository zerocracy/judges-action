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
    (eq what 'code-was-reviewed')
    (exists where)
    (exists seconds)
    (exists when)
    (gt when #{(Time.now - (J.pmp.hr.days_to_reward * 24 * 60 * 60)).utc.iso8601})
    (exists issue)
    (exists repository)
    (exists who)
    (eq is_human 1)
    (join 'merged_when<=when' (and
        (eq what 'pull-was-merged')
        (eq issue $issue)
        (eq repository $repository)))
    (exists merged_when)
    (empty (and
      (eq what '#{$judge}')
      (eq where $where)
      (eq issue $issue)
      (eq repository $repository))))"
  follow 'where repository issue who'
  draw do |n, _resolved|
    n.award = 25
    n.when = Time.now
    n.why = "Code was reviewed in #{J.issue(n)}"
    n.greeting =
      'Thanks for the review! ' \
      "You've earned #{J.award(n)} points for this.#{J.balance(n.who)}"
    "It's time to reward #{J.who(n)} for the code review in " \
      "#{J.issue(n)}, the reward amount is #{J.award(n)}."
  end
end
