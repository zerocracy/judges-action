# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'
require_relative '../../lib/qos_search'

def some_merged_pulls(fact)
  range = Jp.qorange(fact.since, fact.when)
  return { some_merged_pulls: [], some_unmerged_pulls: [] } if range.nil?
  pulls = []
  rejected = []
  Fbe.unmask_repos do |repo|
    break if Fbe.octo.off_quota?
    q = "repo:#{repo} type:pr is:merged closed:#{range}"
    merged = Jp.qosearch(q)
    next if merged.nil?
    break if Fbe.octo.off_quota?
    q = "repo:#{repo} type:pr is:unmerged closed:#{range}"
    found = Jp.qosearch(q)
    next if found.nil?
    pulls << merged[:total_count]
    rejected << found[:total_count]
  end
  {
    some_merged_pulls: pulls,
    some_unmerged_pulls: rejected
  }
end
