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

require 'minitest/autorun'
require 'factbase'
require_relative '../lib/once'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024 Yegor Bugayenko
# License:: MIT
class TestOnce < Minitest::Test
  def test_touch_once
    fb = Factbase.new
    fb.insert
    assert(!each_once(fb, '(always)', judge: 'something').to_a.empty?)
    assert(each_once(fb, '(always)', judge: 'something').to_a.empty?)
  end

  def test_seen_property
    fb = Factbase.new
    f1 = fb.insert
    f1.foo = 42
    assert_equal(1, each_tuple_once(fb, '(eq foo 42)', judge: 'x').to_a.size)
    assert(each_tuple_once(fb, '(eq foo 42)', judge: 'x').to_a.empty?)
  end

  def test_seen_all_or_nothing
    fb = Factbase.new
    f1 = fb.insert
    f1.a = 1
    assert(each_tuple_once(fb, '(exists a)', '(exists b)', judge: 'x').to_a.empty?)
    f2 = fb.insert
    f2.b = 1
    assert(!each_tuple_once(fb, '(exists a)', '(exists b)', judge: 'x').to_a.empty?)
    assert(each_tuple_once(fb, '(exists a)', '(exists b)', judge: 'x').to_a.empty?)
  end

  def test_with_txn
    fb = Factbase.new
    f1 = fb.insert
    f1.foo = 42
    each_tuple_once(fb, '(exists foo)', judge: 'xx') do |fs|
      fb.txn do |fbt|
        f = fbt.insert
        f.bar = 1
      end
      fs[0].xyz = 'hey'
    end
    assert_equal(1, fb.query('(exists seen)').each.to_a.size)
    assert_equal(1, fb.query('(exists bar)').each.to_a.size)
    assert_equal(1, fb.query('(exists xyz)').each.to_a.size)
  end

  def test_with_chain_txn
    fb = Factbase.new
    f1 = fb.insert
    f1.foo = 42
    each_tuple_once_txn(fb, '(exists foo)', judge: 'xx') do |fbt, ff|
      f = fbt.insert
      f.bar = 1
      ff.xyz = 'hey'
    end
    assert_equal(1, fb.query('(exists seen)').each.to_a.size)
    assert_equal(1, fb.query('(exists bar)').each.to_a.size)
    assert_equal(1, fb.query('(exists xyz)').each.to_a.size)
  end
end
