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

require 'fbe/fb'
require 'fbe/octo'
require 'fbe/overwrite'
require 'fbe/github_graph'
require 'fbe/unmask_repos'

unless Fbe.fb.query(
  "(and
    (eq what '#{$judge}')
    (gt when (minus (to_time (env 'TODAY' '#{Time.now.utc.iso8601}')) '1 days')))"
).each.to_a.empty?
  $loog.debug("#{$judge} statistics have recently been collected, skipping now")
  return
end

f = Fbe.fb.insert
f.what = $judge
f.when = Time.now

Dir[File.join(__dir__, 'total_*.rb')].each do |rb|
  n = File.basename(rb).gsub(/\.rb$/, '')
  next unless f[n].nil?
  if Fbe.octo.off_quota
    $loog.info('No GitHub quota left, it is time to stop')
    break
  end
  require_relative rb
  send(n, f).each { |k, v| f = Fbe.overwrite(f, k.to_s, v) }
end
