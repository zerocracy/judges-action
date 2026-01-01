# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/fb'
require 'fbe/octo'
require 'fbe/unmask_repos'

# Some triage time for issues
#
# This function is called from the "quality-of-service.rb".
#
# @param [Factbase::Fact] fact The fact just under processing
# @return [Hash] Map with keys as fact attributes and values as integers
def some_triage_time(fact)
  triage_times = []
  Fbe.unmask_repos do |repo|
    Fbe.octo.search_issues(
      "repo:#{repo} type:issue created:#{fact.since.utc.iso8601}..#{fact.when.utc.iso8601}"
    )[:items].each do |issue|
      ff = Fbe.fb.query(
        "
        (and
          (eq repository #{Fbe.octo.repo_id_by_name(repo)})
          (eq issue #{issue[:number]})
          (eq what 'label-was-attached')
          (or
            (eq label 'bug')
            (eq label 'enhancement'))
          (absent stale)
          (exists when)
          (eq where 'github'))
        "
      ).each.min_by(&:when)
      triage_times << (ff.when - issue[:created_at]) if ff
    end
  end
  {
    some_triage_time: triage_times
  }
end
