# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'
require_relative '../../lib/qos_search'

def some_merged_pulls(fact)
  pulls = []
  rejected = []
  Fbe.unmask_repos do |repo|
    return {} if Fbe.octo.off_quota?
    q = "repo:#{repo} type:pr is:merged closed:#{fact.since.utc.iso8601}..#{fact.when.utc.iso8601}"
    found = Jp.qosearch(q)
    return {} if found.nil?
    pulls << found[:total_count]
    return {} if Fbe.octo.off_quota?
    q = "repo:#{repo} type:pr is:unmerged closed:#{fact.since.utc.iso8601}..#{fact.when.utc.iso8601}"
    found = Jp.qosearch(q)
    return {} if found.nil?
    rejected << found[:total_count]
  end
  {
    some_merged_pulls: pulls,
    some_unmerged_pulls: rejected
  }
end
