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
    (exists hoc)
    (exists comments)
    (exists when)
    (gt when #{(Time.now - (J.pmp.hr.days_to_reward * 24 * 60 * 60)).utc.iso8601})
    (exists issue)
    (exists repository)
    (exists who)
    (eq is_human 1)
    (join 'author<=who' (and
        (eq what 'pull-was-opened')
        (eq issue $issue)
        (eq repository $repository)))
    (exists author)
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
  draw do |n, reviewed|
    a = J.award(
      {
        kind: :const,
        points: 25,
        because: 'as a basis'
      },
      {
        if: reviewed.who == reviewed.author,
        kind: :const,
        points: -40,
        because: 'for reviewing your own contribution'
      },
      {
        if: reviewed.who != reviewed.author,
        kind: :linear,
        x: reviewed.hoc,
        k: 0.1,
        because: "for #{reviewed.hoc} hits-of-code",
        max: 40,
        at_least: 5
      },
      {
        if: reviewed.who != reviewed.author,
        kind: :linear,
        x: reviewed.comments,
        k: 1,
        because: "for #{reviewed.comments} comments",
        max: 20,
        at_least: 5
      },
      {
        kind: :at_most,
        points: 100,
        because: 'it is too many'
      },
      {
        kind: :at_least,
        points: 5,
        because: 'it is too few'
      }
    )
    n.award = a[:points]
    n.when = Time.now
    n.why = "Code was reviewed in #{J.issue(n)}"
    n.greeting = [
      'Thanks for the review!',
      a[:greeting],
      J.balance(n.who)
    ].join(' ')
    "It's time to reward #{J.who(n)} for the code review in " \
      "#{J.issue(n)}, the reward amount is #{n.award}."
  end
end
