# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'

# Total number of unique active contributors to all repos
#
# This function is called from the "dimensions-of-terrain.rb".
#
# @param [Factbase::Fact] fact The fact just under processing
# @return [Hash] Map with keys as fact attributes and values as integers
def total_active_contributors(fact)
  active_contributors = Set.new
  Fbe.unmask_repos do |repo|
    Fbe.octo.search_commits(
      "repo:#{repo} author-date:>#{(fact.when - (30 * 24 * 60 * 60)).iso8601[0..9]}"
    )[:items].each do |commit|
      author_id = commit.dig(:author, :id)
      active_contributors << author_id unless author_id.nil?
    end
  end
  { total_active_contributors: active_contributors.count }
end
