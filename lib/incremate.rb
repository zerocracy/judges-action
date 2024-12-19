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

require 'time'
require 'fbe/octo'
require 'fbe/overwrite'
require_relative 'jp'

# Incrementaly accumulates data into a fact, using Ruby scripts
# found in the directory provided, by the prefix.
def Jp.incremate(fact, dir, prefix)
  start = Time.now
  Dir[File.join(dir, "#{prefix}_*.rb")].each do |rb|
    n = File.basename(rb).gsub(/\.rb$/, '')
    next unless fact[n].nil?
    if Fbe.octo.off_quota
      $loog.info('No GitHub quota left, it is time to stop')
      break
    end
    if Time.now - start > 5 * 60
      $loog.info('We are doing this for too long, time to stop')
      break
    end
    require_relative rb
    send(n, fact).each { |k, v| fact = Fbe.overwrite(fact, k.to_s, v) }
  end
end
