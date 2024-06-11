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

require 'factbase/tuples'

# Returns a decorated global factbase, which only touches facts once.
def each_once(fb, query, judge: $judge)
  return to_enum(__method__, fb, query, judge:) unless block_given?
  q = "(and #{query} (not (eq seen '#{judge}')))"
  fb.query(q).each do |f|
    yield f
    f.seen = judge
  end
end

# Returns a decorated global factbase, which only touches a tuple once.
def each_tuple_once(fb, *queries, judge: $judge)
  return to_enum(__method__, fb, *queries, judge:) unless block_given?
  qq = queries.map { |q| "(and #{q} (not (eq seen '#{judge}')))" }
  Factbase::Tuples.new(fb, qq).each do |fs|
    yield fs
    fs.each do |f|
      f.seen = judge
    end
  end
end

def each_tuple_once_txn(fb, *queries, judge: $judge)
  fb.txn do |fbt|
    each_tuple_once(fbt, *queries, judge:) do |fs|
      yield [fbt] + fs
    end
  end
end
