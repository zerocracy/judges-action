# frozen_string_literal: true

# Copyright (c) 2024 Yegor Bugayenko
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the 'Software'), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

require 'minitest/autorun'
require 'tmpdir'
require 'factbase'
require 'factbase/looged'
require 'loog'
require_relative '../lib/if_absent'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024 Yegor Bugayenko
# License:: MIT
class TestIfAbsent < Minitest::Test
  def test_ignores
    fb = Factbase.new
    fb.insert.foo = 'hello dude'
    n = if_absent(fb) do |f|
      f.foo = 'hello dude'
    end
    assert(n.nil?)
  end

  def test_ignores_with_time
    fb = Factbase.new
    t = Time.now
    fb.insert.foo = t
    n = if_absent(fb) do |f|
      f.foo = t
    end
    assert(n.nil?)
  end

  def test_injects
    fb = Factbase.new
    n = if_absent(fb) do |f|
      f.foo = 42
    end
    assert_equal(42, n.foo)
  end

  def test_injects_and_reads
    if_absent(Factbase.new) do |f|
      f.foo = 42
      assert_equal(42, f.foo)
    end
  end

  def test_complex_ignores
    fb = Factbase.new
    f1 = fb.insert
    f1.foo = 'hello, "dude"!'
    f1.abc = 42
    t = Time.now
    f1.z = t
    f1.bar = 3.14
    n = if_absent(fb) do |f|
      f.foo = 'hello, "dude"!'
      f.abc = 42
      f.z = t
      f.bar = 3.14
    end
    assert(n.nil?)
  end

  def test_complex_injects
    fb = Factbase.new
    f1 = fb.insert
    f1.foo = 'hello, dude!'
    f1.abc = 42
    t = Time.now
    f1.z = t
    f1.bar = 3.14
    n = if_absent(fb) do |f|
      f.foo = "hello, \\\"dude\\\" \\' \\' ( \n\n ) (!   '"
      f.abc = 42
      f.z = t + 1
      f.bar = 3.15
    end
    assert(!n.nil?)
  end
end
