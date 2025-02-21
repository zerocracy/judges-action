# frozen_string_literal: true

# MIT License
#
# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'

# Total number of unique contributors in all repos
#
# This function is called from the "dimensions-of-terrain.rb".
#
# @param [Factbase::Fact] fact The fact just under processing
# @return [Hash] Map with keys as fact attributes and values as integers
def total_contributors(_fact)
  contributors = Set.new
  Fbe.unmask_repos.each do |repo|
    next if Fbe.octo.repository(repo)[:size].zero?
    Fbe.octo.contributors(repo).each do |contributor|
      contributors << contributor[:id]
    end
  end
  { total_contributors: contributors.count }
end
