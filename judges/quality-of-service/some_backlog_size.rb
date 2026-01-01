# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'

# Some issues
#
# This function is called from the "quality-of-service.rb".
#
# @param [Factbase::Fact] fact The fact just under processing
# @return [Hash] Map with keys as fact attributes and values as integers
def some_backlog_size(fact)
  issues = []
  Fbe.unmask_repos do |repo|
    (fact.since.utc.to_date..fact.when.utc.to_date).last(7).each do |date|
      return {} if Fbe.octo.off_quota?
      count = 0
      Fbe.octo.search_issues(
        "repo:#{repo} type:issue created:*..#{date.iso8601[0..9]} (closed:>=#{date.iso8601[0..9]} OR state:open)",
        advanced_search: true
      )[:items].each do |item|
        count += 1 if item[:closed_at].nil? || item[:closed_at].utc.to_date >= date
      end
      issues << count
    end
  end
  { some_backlog_size: issues }
end
