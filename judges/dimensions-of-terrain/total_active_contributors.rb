# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'
require_relative '../../lib/qos_search'

def total_active_contributors(fact)
  seen = Set.new
  Fbe.unmask_repos do |repo|
    commits = Jp.qosearch(
      "repo:#{repo} author-date:>#{(fact.when - (30 * 24 * 60 * 60)).iso8601[0..9]}",
      kind: :commits
    )
    next if commits.nil?
    commits[:items].each do |commit|
      author = commit.dig(:author, :id)
      seen << author unless author.nil?
    end
  end
  { total_active_contributors: seen.count }
end
