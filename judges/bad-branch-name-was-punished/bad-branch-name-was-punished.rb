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
    (eq what 'pull-was-opened')
    (exists where)
    (eq where 'github')
    (exists who)
    (eq is_human 1)
    (exists when)
    (exists issue)
    (exists repository)
    (exists branch)
    (not (matches branch '^[0-9]+$'))
    (empty (and
      (eq what '#{$judge}')
      (eq where $where)
      (eq issue $issue)
      (eq repository $repository))))"
  follow 'where repository issue who branch'
  draw do |n, opened|
    a = J.award(
      {
        basis: true,
        kind: :const,
        points: -10,
        because: 'as a basis'
      }
    )
    n.award = a[:points]
    n.when = Time.now
    n.why = "Branch name was wrong in #{J.issue(n)}"
    n.greeting = [
      'It is [not a good idea](https://www.yegor256.com/2014/04/15/github-guidelines.html) ',
      "to name Git branches the way you named this one: \"`#{opened.branch}`\". ",
      a[:greeting],
      'Next time, give your branch the same name as the number of the ticket that you are solving. ',
      "In this case, a perfect name, for example, would be \"`#{opened.issue}`\". ",
      J.balance(n.who)
    ].join
    "It's time to punish #{J.who(n)} for the branch named wrong in " \
      "#{J.issue(n)}, the penalty amount is #{n.award}."
  end
end
