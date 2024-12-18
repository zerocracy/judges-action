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
require 'fbe/unmask_repos'

# Average triage time for issues
#
# This function is called from the "quality-of-service.rb".
#
# @param [Factbase::Fact] fact The fact just under processing
# @return [Hash] Map with keys as fact attributes and values as integers
def average_triage_time(fact)
  triage_times = []
  Fbe.unmask_repos.each do |repo|
    Fbe.octo.search_issues("repo:#{repo} type:issue created:>#{fact.since.utc.iso8601[0..9]}")[:items].each do |issue|
      ff = Fbe.fb.query(
        <<~QUERY
          (and
            (eq where 'github')
            (eq repository #{Fbe.octo.repo_id_by_name(repo)})
            (eq issue #{issue[:number]})
            (eq what 'label-was-attached')
            (exists when)
            (or
              (eq label 'bug')
              (eq label 'enhancement')
            )
          )
        QUERY
      ).each.min_by(&:when)
      triage_times << (ff.when - issue[:created_at]) if ff
    end
  end
  { average_triage_time: triage_times.empty? ? 0 : triage_times.sum.to_f / triage_times.size }
end
