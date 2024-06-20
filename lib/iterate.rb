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

require_relative 'unmask_repos'
require_relative 'octo'
require_relative 'fb'

# Create a conclude code block.
def iterate(fbx = fb, loog = $loog, &)
  c = Iterate.new(fbx, loog)
  c.instance_eval(&)
end

# Iterate.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024 Zerocracy
# License:: MIT
class Iterate
  def initialize(fb, loog)
    @fb = fb
    @loog = loog
    @label = nil
    @since = 0
    @query = nil
    @limit = 100
    @quota_aware = false
  end

  def quota_aware
    @quota_aware = true
  end

  def limit(limit)
    raise 'Cannot set "limit" to nil' if limit.nil?
    @limit = limit
  end

  def by(query)
    raise 'Query is already set' unless @query.nil?
    raise 'Cannot set query to nil' if query.nil?
    @query = query
  end

  def as(label)
    raise 'Label is already set' unless @label.nil?
    raise 'Cannot set "label" to nil' if label.nil?
    @label = label
  end

  def over(&)
    raise 'Use "as" first' if @label.nil?
    raise 'Use "by" first' if @query.nil?
    seen = {}
    oct = octo(loog: @loog)
    repos = unmask_repos(loog: @loog)
    loop do
      repos.each do |repo|
        seen[repo] = 0 if seen[repo].nil?
        next if seen[repo] > @limit
        rid = oct.repo_id_by_name(repo)
        before = fb.query("(agg (and (eq what '#{@label}') (eq repository #{rid})) (first latest))").one
        fb.query("(and (eq what '#{@label}') (eq repository #{rid}))").delete!
        before = before.nil? ? @since : before[0]
        nxt = fb.query(@query).one(before:, repository: rid)
        after = nxt.nil? ? @since : yield(rid, nxt)
        raise "Iterator must return an Integer, while #{after.class} returned" unless after.is_a?(Integer)
        f = fb.insert
        f.repository = rid
        f.latest = after.nil? ? nxt : after
        f.what = @label
        seen[repo] += 1
        break if oct.off_quota
      end
      break if oct.off_quota
      unless seen.values.any? { |v| v < @limit }
        @loog.debug("Finished scanning #{repos.size} repos: #{seen.map { |k, v| "#{k}:#{v}" }.join(', ')}")
        break
      end
    end
  end
end
