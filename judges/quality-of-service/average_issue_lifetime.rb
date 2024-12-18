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
require 'fbe/unmask_repos'

# Issue and PR lifetimes:
#
# This function is called from the "quality-of-service.rb".
#
# @param [Factbase::Fact] fact The fact just under processing
# @return [Hash] Map with keys as fact attributes and values as integers
def average_issue_lifetime(fact)
  ret = {}
  { issue: 'average_issue_lifetime', pr: 'average_pull_lifetime' }.each do |type, prop|
    ages = []
    Fbe.unmask_repos.each do |repo|
      q = "repo:#{repo} type:#{type} closed:>#{fact.since.utc.iso8601[0..9]}"
      ages +=
        Fbe.octo.search_issues(q)[:items].map do |json|
          next if json[:closed_at].nil?
          next if json[:created_at].nil?
          json[:closed_at] - json[:created_at]
        end
    end
    ages.compact!
    ret[prop] = ages.empty? ? 0 : ages.inject(&:+).to_f / ages.size
  end
  ret
end
