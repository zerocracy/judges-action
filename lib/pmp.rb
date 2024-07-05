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

require 'others'
require 'fbe/fb'

# Project management functions.
module J; end

def J.pmp
  defaults = {
    hr: {
      days_to_reward: 7,
      days_of_running_balance: 28
    }
  }
  others do |*args1|
    area = args1.first
    d = defaults[area]
    raise "Unknown area 'pmp.#{area}'" if d.nil?
    others do |*args2|
      param = args2.first
      d = d[param]
      raise "Unknown parameter 'pmp.#{area}.#{param}'" if d.nil?
      f = Fbe.fb.query("(and (eq what 'pmp') (eq area '#{area}'))").each.to_a.first
      if f.nil?
        d
      else
        r = f[param]
        if r.nil?
          d
        else
          r.first
        end
      end
    end
  end
end
