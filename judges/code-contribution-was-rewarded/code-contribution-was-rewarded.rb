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
    (eq what 'code-was-contributed')
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
    (empty (and
      (eq what '#{$judge}')
      (eq where $where)
      (eq issue $issue)
      (eq repository $repository))))"
  follow 'where repository issue who'
  draw do |n, contrib|
    a = J.award(
      {
        kind: :const,
        points: 20,
        because: 'as a basis'
      },
      {
        if: contrib.hoc < 100,
        kind: :linear,
        x: contrib.hoc,
        k: 0.1,
        because: "for #{contrib.hoc} hits-of-code",
        max: 40,
        at_least: 5
      },
      {
        if: contrib.hoc >= 100,
        kind: :const,
        points: -7,
        because: "for too many hits-of-code (#{contrib.hoc})"
      },
      {
        if: contrib.hoc >= 400,
        kind: :const,
        points: -15,
        because: "for way too many hits-of-code (#{contrib.hoc})"
      },
      {
        kind: :linear,
        x: contrib.comments,
        k: -1,
        because: "for #{contrib.comments} comments",
        min: -20,
        at_least: -5
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
    n.why = "Code was contributed in #{J.issue(n)}"
    n.greeting = [
      'Thanks for the contribution! ',
      a[:greeting],
      'Please, [keep](https://www.yegor256.com/2018/03/06/speed-vs-quality.html) them coming. ',
      J.balance(n.who)
    ].join
    "It's time to reward #{J.who(n)} for the code contributed in " \
      "#{J.issue(n)}, the reward amount is #{n.award}."
  end
end
