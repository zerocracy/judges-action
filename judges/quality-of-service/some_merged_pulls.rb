# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'

def some_merged_pulls(fact)
  pulls = []
  rejected = []
  Fbe.unmask_repos do |repo|
    pulls << Fbe.octo.search_issues(
      "repo:#{repo} type:pr is:merged closed:#{fact.since.utc.iso8601}..#{fact.when.utc.iso8601}"
    )[:total_count]
    rejected << Fbe.octo.search_issues(
      "repo:#{repo} type:pr is:unmerged closed:#{fact.since.utc.iso8601}..#{fact.when.utc.iso8601}"
    )[:total_count]
  end
  {
    some_merged_pulls: pulls,
    some_unmerged_pulls: rejected
  }
end
