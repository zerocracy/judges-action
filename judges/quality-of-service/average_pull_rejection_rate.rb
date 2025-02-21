# frozen_string_literal: true

# MIT License
#
# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'

# Rejection PR rate
#
# This function is called from the "quality-of-service.rb".
#
# @param [Factbase::Fact] fact The fact just under processing
# @return [Hash] Map with keys as fact attributes and values as integers
def average_pull_rejection_rate(fact)
  pulls = 0
  rejected = 0
  Fbe.unmask_repos.each do |repo|
    pulls += Fbe.octo.search_issues("repo:#{repo} type:pr closed:>#{fact.since.utc.iso8601[0..9]}")[:total_count]
    rejected += Fbe.octo.search_issues(
      "repo:#{repo} type:pr is:unmerged closed:>#{fact.since.utc.iso8601[0..9]}"
    )[:total_count]
  end
  { average_pull_rejection_rate: pulls.zero? ? 0 : rejected.to_f / pulls }
end
