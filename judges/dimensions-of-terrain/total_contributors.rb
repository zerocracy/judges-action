# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'

# Calculates the total number of unique contributors across all monitored GitHub repositories.
# This function creates a set of unique contributor IDs from all repositories, ensuring
# each contributor is counted only once even if they contribute to multiple repositories.
# Empty repositories (size zero) are skipped.
#
# This function is called from the "dimensions-of-terrain.rb" using the incremate
# helper to collect this specific metric as part of repository dimensions analysis.
#
# @param [Factbase::Fact] fact The fact object currently being processed (unused)
# @return [Hash] Map with total_contributors count as a key-value pair
# @see ../dimensions-of-terrain.rb Main judge that calls this function
def total_contributors(_fact)
  contributors = Set.new
  Fbe.unmask_repos do |repo|
    json = Fbe.octo.repository(repo)
    next if json[:size].nil? || json[:size].zero?
    Fbe.octo.contributors(repo).each do |contributor|
      contributors << contributor[:id]
    end
  end
  { total_contributors: contributors.count }
end
