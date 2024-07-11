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
require_relative '../lib/award'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024 Yegor Bugayenko
# License:: MIT
class TestAward < Minitest::Test
  def test_simple
    a = J.award(
      {
        kind: :const,
        points: 20,
        because: 'as a basis'
      },
      {
        kind: :linear,
        x: 123,
        k: 0.1,
        because: 'for 123 hits-of-code',
        max: 40,
        min: 5
      },
      {
        kind: :linear,
        x: 3,
        k: -1,
        because: 'for 3 comments',
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
    assert(a[:points] <= 100)
    assert(a[:points] >= 5)
    assert_equal(32, a[:points])
    assert(a[:greeting].include?('You\'ve earned +32 points for this'))
    assert(!a[:greeting].include?('for 3 comments'))
  end

  def test_only_basis
    a = J.award(
      {
        basis: true,
        kind: :const,
        points: 20,
        because: 'as a basis'
      },
      {
        kind: :const,
        if: false,
        points: 100,
        because: '...'
      }
    )
    assert_equal(20, a[:points])
    assert_equal('You\'ve earned +20 points for this. ', a[:greeting])
  end
end
