# frozen_string_literal: true

# MIT License
#
# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'

# Total number of stars and forks for all repos:
#
# This function is called from the "dimensions-of-terrain.rb".
#
# @param [Factbase::Fact] fact The fact just under processing
# @return [Hash] Map with keys as fact attributes and values as integers
def total_stars(_fact)
  stars = 0
  forks = 0
  Fbe.unmask_repos.each do |repo|
    Fbe.octo.repository(repo).then do |json|
      stars += json[:stargazers_count]
      forks += json[:forks]
    end
  end
  { total_stars: stars, total_forks: forks }
end
