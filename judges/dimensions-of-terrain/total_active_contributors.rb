# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'

def total_active_contributors(fact)
  guard = $terrainguard
  seen = Set.new
  since = (fact.when - (30 * 24 * 60 * 60)).iso8601[0..9]
  guard.eachrepo do |repo|
    json = guard.searchcommits(repo, since)
    next if json.nil?
    json[:items].each do |commit|
      author = commit.dig(:author, :id)
      seen << author unless author.nil?
    end
  end
  { total_active_contributors: seen.count }
end
