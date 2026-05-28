# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'

def total_active_contributors(fact)
  seen = Set.new
  since = (fact.when - (30 * 24 * 60 * 60)).iso8601[0..9]
  TerrainOcto.repos do |repo|
    json = TerrainOcto.safe(repo, 'commit search') { Fbe.octo.search_commits("repo:#{repo} author-date:>#{since}") }
    next if json.nil?
    json[:items].each do |commit|
      author = commit.dig(:author, :id)
      seen << author unless author.nil?
    end
  end
  { total_active_contributors: seen.count }
end
