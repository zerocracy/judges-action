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

require 'fbe/octo'

# Supplementary functions.
module J; end

def J.award(*rows)
  bills = []
  rows.each do |row|
    next if !row[:if].nil? && !row[:if]
    case row[:kind]
    when :const
      v = row[:points]
    when :linear
      v = row[:x] * row[:k]
    when :at_most
      sum = bills.map { |b| b[:v] }.inject(&:+)
      diff = row[:points] - sum
      v = diff.negative? ? diff : 0
    when :at_least
      sum = bills.map { |b| b[:v] }.inject(&:+)
      diff = row[:points] - sum
      v = diff.positive? ? diff : 0
    else
      raise "Unknown kind of row '#{row[:kind]}'"
    end
    v = [v, row[:max]].min unless row[:max].nil?
    v = [v, row[:min]].max unless row[:min].nil?
    v = 0 if !row[:at_least].nil? && v.abs < row[:at_least].abs
    bills << { v:, reason: "#{format('%+d', v)} #{row[:because]}" }
  end
  bills.compact!
  bills.reject! { |b| b[:v].zero? }
  total = bills.map { |b| b[:v] }.inject(&:+).to_i
  explain = bills.map { |b| b[:reason] }.join(', ')
  {
    points: total,
    greeting: "You've earned #{format('%+d', total)} points for this (#{explain}). "
  }
end
