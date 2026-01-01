# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'

# Some merged and unmerged PR
#
# This function is called from the "quality-of-service.rb".
#
# @param [Factbase::Fact] fact The fact just under processing
# @return [Hash] Map with keys as fact attributes and values as integers
def some_merged_pulls(fact)
  pulls = []
  rejected = []
  Fbe.unmask_repos do |repo|
    pulls << Fbe.octo.search_issues(
      "repo:#{repo} type:pr closed:#{fact.since.utc.iso8601}..#{fact.when.utc.iso8601}"
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
