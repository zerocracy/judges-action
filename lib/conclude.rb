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

require 'judges/fb/chain'

# Conclude.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024 Zerocracy
# License:: MIT
class Conclude
  def initialize(fb, judge, loog)
    @fb = fb
    @judge = judge
    @loog = loog
    @queries = []
    @follows = {}
  end

  def on(query)
    @queries << query
  end

  def follow(props)
    @follows[@queries.size - 1] = props.split
  end

  def draw
    chain_txn(@fb, *@queries, judge: @judge) do |a|
      fbt = a.shift
      n = fbt.insert
      @follows.each do |i, props|
        props.each do |p|
          v = a[i].send(p)
          n.send("#{p}=", v)
        end
      end
      n.details = yield [n] + a
      $loog.debug("#{@judge}: #{n.details}")
      n.what = @judge
    end
  end
end

def conclude(fb = $fb, judge = $judge, loog = $loog, &)
  c = Conclude.new(fb, judge, loog)
  c.instance_eval(&)
end
