# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/fb'
require 'fbe/octo'
require 'fbe/pmp'
require 'fbe/unmask_repos'

def some_triage_time(fact)
  threshold = Fbe.pmp.quality.qos_min_triage_seconds.value || 60
  times = []
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
      next unless ff
      delta = ff.when - issue[:created_at]
      next if delta < threshold
      times << delta
    end
  end
  {
    some_triage_time: times
  }
end
