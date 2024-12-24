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
require 'tago'
require 'fbe/octo'
require 'fbe/overwrite'
require_relative 'jp'

# Incrementaly accumulates data into a fact, using Ruby scripts
# found in the directory provided, by the prefix.
#
# @param [Factbase::Fact] fact The fact to put data into (some data already there)
# @param [String] dir Where to find Ruby scripts
# @param [String] prefix The prefix to use for scripts (e.g. "total")
# @return nil
def Jp.incremate(fact, dir, prefix)
  start = Time.now
  Dir[File.join(dir, "#{prefix}_*.rb")].shuffle.each do |rb|
    n = File.basename(rb).gsub(/\.rb$/, '')
    unless fact[n].nil?
      $loog.info("#{n} is here: #{fact[n].first}")
      next
    end
    if Fbe.octo.off_quota
      $loog.info('No GitHub quota left, it is time to stop')
      break
    end
    if Time.now - start > 5 * 60
      $loog.info("We are doing this for too long (#{start.ago}), time to stop")
      break
    end
    require_relative rb
    before = Time.now
    h = send(n, fact)
    h.each { |k, v| fact = Fbe.overwrite(fact, k.to_s, v) }
    $loog.info("Collected #{n} in #{before.ago} (#{start.ago} total): [#{h.map { |k, v| "#{k}: #{v}" }.join(', ')}]")
  end
end
