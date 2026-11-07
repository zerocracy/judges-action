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
    break if Fbe.octo.off_quota?
    merged = Jp.merged(repo, fact)
    next if merged.nil?
    break if Fbe.octo.off_quota?
    found = Jp.qosearch("repo:#{repo} type:pr is:unmerged closed:#{fact.since.utc.iso8601}..#{fact.when.utc.iso8601}")
    next if found.nil?
    pulls << merged[:total_count]
    rejected << found[:total_count]
  end
  {
    some_merged_pulls: pulls,
    some_unmerged_pulls: rejected
  }
end
