# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'

# Calculates the total number of stars and forks across all monitored GitHub repositories.
# This function counts stargazers and fork counts for each repository and
# returns the aggregated totals, which are important indicators of repository
# popularity and community engagement.
#
# This function is called from the "dimensions-of-terrain.rb" using the incremate
# helper to collect these specific metrics as part of repository dimensions analysis.
#
# @param [Factbase::Fact] fact The fact object currently being processed (unused)
# @return [Hash] Map with total_stars and total_forks counts as key-value pairs
# @see ../dimensions-of-terrain.rb Main judge that calls this function
def total_stars(_fact)
  stars = 0
  forks = 0
  Fbe.unmask_repos do |repo|
    Fbe.octo.repository(repo).then do |json|
      stars += json[:stargazers_count]
      forks += json[:forks]
    end
  end
  { total_stars: stars, total_forks: forks }
end
