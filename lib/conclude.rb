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

# Create a conclude code block.
def conclude(fbx = fb, judge = $judge, loog = $loog, &)
  c = Conclude.new(fbx, judge, loog)
  c.instance_eval(&)
end

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
    @follows = []
    @threshold = 9999
    @quota_aware = false
  end

  def quota_aware
    @quota_aware = true
  end

  def on(query)
    @queries << query
  end

  def threshold(max)
    @threshold = max
  end

  def follow(props)
    @follows = props.split
  end

  def draw(&)
    roll do |fbt, a|
      n = fbt.insert
      fill(n, a, &)
      n
    end
  end

  def maybe(&)
    roll do |fbt, a|
      if_absent(fbt) do |n|
        fill(n, a, &)
      end
    end
  end

  def consider(&)
    roll do |_fbt, a|
      f = a.shift
      fill(f, a, &)
      nil
    end
  end

  def look(&)
    roll do |_fbt, a|
      yield a
      nil
    end
  end

  private

  def roll(&)
    catch :stop do
      passed = 0
      each_tuple_once_txn(@fb, *@queries, judge: @judge) do |a|
        throw :stop if @quota_aware && octo.off_quota
        throw :stop if passed >= @threshold
        fbt = a.shift
        n = yield fbt, a
        @loog.info("#{n.what}: #{n.details}") unless n.nil?
        passed += 1
      end
    end
  end

  def fill(fact, others)
    @follows.each do |follow|
      i = @queries.size - 1
      if follow.include?('.')
        i, follow = follow.split('.')
        i = i[1..].to_i
      end
      v = others[i].send(follow)
      fact.send("#{follow}=", v)
      fact.cause = others[i]._id
    end
    r = yield [fact] + others
    return unless r.is_a?(String)
    fact.details = r
    fact.what = @judge
  end
end
