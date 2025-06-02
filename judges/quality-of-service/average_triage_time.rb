# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

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
        "
        (and
          (eq where 'github')
          (eq repository #{Fbe.octo.repo_id_by_name(repo)})
          (eq issue #{issue[:number]})
          (eq what 'label-was-attached')
          (exists when)
          (or
            (eq label 'bug')
            (eq label 'enhancement')))
        "
      ).each.min_by(&:when)
      triage_times << (ff.when - issue[:created_at]) if ff
    end
  end
  { average_triage_time: triage_times.empty? ? 0 : triage_times.sum.to_f / triage_times.size }
end
