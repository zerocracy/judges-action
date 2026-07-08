# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'
require_relative '../../lib/qos_search'

def some_backlog_size(fact)
  return {} if Fbe.octo.off_quota?(resource: :search)
  issues = []
  Fbe.unmask_repos do |repo|
    (fact.since.utc.to_date..fact.when.utc.to_date).last(7).each do |date|
      return {} if Fbe.octo.off_quota?(resource: :search)
      count = 0
      found = Jp.qosearch(
        "repo:#{repo} type:issue created:*..#{date.iso8601[0..9]} (closed:>=#{date.iso8601[0..9]} OR state:open)",
        advanced_search: true
      )
      return {} if found.nil?
      found[:items].each do |item|
        count += 1 if item[:closed_at].nil? || item[:closed_at].utc.to_date >= date
      end
      issues << count
    end
  end
  { some_backlog_size: issues }
end
