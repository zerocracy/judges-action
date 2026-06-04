# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/fb'
require 'fbe/octo'
require 'fbe/pmp'
require 'fbe/unmask_repos'
require_relative '../../lib/qos_search'

def some_triage_time(fact)
  threshold = Fbe.pmp.quality.qos_min_triage_seconds.value || 60
  times = []
  Fbe.unmask_repos do |repo|
    return {} if Fbe.octo.off_quota?
    found = Jp.qosearch("repo:#{repo} type:issue created:#{fact.since.utc.iso8601}..#{fact.when.utc.iso8601}")
    return {} if found.nil?
    found[:items].each do |issue|
      # rubocop:disable Elegant/NoRedundantVariable -- cannot inline due to nested string interpolation
      rid =
        begin
          Fbe.octo.repo_id_by_name(repo)
        rescue Octokit::NotFound, Octokit::Deprecated => e
          $loog.info("Repository #{repo} not found: #{e.message}")
          next
        rescue Octokit::Forbidden => e
          $loog.warn(
            "[#{$judge}] Access forbidden to repository lookup for #{repo} " \
            "(transient, will retry next cycle): #{e.class}: #{e.message}"
          )
          next
        end
      # rubocop:enable Elegant/NoRedundantVariable
      ff = Fbe.fb.query(
        "
        (and
          (eq repository #{rid})
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
