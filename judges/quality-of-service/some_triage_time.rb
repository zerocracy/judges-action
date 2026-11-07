# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/fb'
require 'fbe/octo'
require 'fbe/pmp'
require 'fbe/unmask_repos'
require_relative '../../lib/qos_search'

Jp::TRIAGE_LAG_SECONDS = 24 * 60 * 60

def some_triage_time(fact)
  # rubocop:disable Elegant/NoComments
  # shortcut: label facts arriving >1 day after the window end are lost, raise the lag if batches fall further behind
  # rubocop:enable Elegant/NoComments
  return {} if Time.now - fact.when < Jp::TRIAGE_LAG_SECONDS
  threshold = Fbe.pmp.quality.qos_min_triage_seconds.value || 60
  times = []
  Fbe.unmask_repos do |repo|
    return {} if Fbe.octo.off_quota?
    found = Jp.qosearch("repo:#{repo} type:issue created:#{fact.since.utc.iso8601}..#{fact.when.utc.iso8601}")
    return {} if found.nil?
    rid =
      begin
        Fbe.octo.repo_id_by_name(repo)
      rescue Fbe::Error, Octokit::NotFound, Octokit::Deprecated => e
        $loog.info("Repository #{repo} not accessible: #{e.message}")
        next
      rescue Octokit::Forbidden => e
        $loog.warn(
          "[#{$judge}] Access forbidden to #{repo} " \
          "(transient, will retry next cycle): #{e.class}: #{e.message}"
        )
        next
      end
    found[:items].each do |issue|
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
          (lte when (to_time '#{fact.when.utc.iso8601(9)}'))
          (eq where 'github'))
        "
      ).each.min_by(&:when)
      next unless ff
      next unless issue[:created_at]
      delta = ff.when - issue[:created_at]
      next if delta < threshold
      times << delta
    end
  end
  {
    some_triage_time: times
  }
end
