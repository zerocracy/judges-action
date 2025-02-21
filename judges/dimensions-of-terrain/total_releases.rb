# frozen_string_literal: true

# MIT License
#
# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'

# Total number of releases ever made:
#
# This function is called from the "dimensions-of-terrain.rb".
#
# @param [Factbase::Fact] fact The fact just under processing
# @return [Hash] Map with keys as fact attributes and values as integers
def total_releases(_fact)
  total = 0
  Fbe.unmask_repos.each do |repo|
    Fbe.octo.releases(repo).each do |_|
      total += 1
    end
  end
  { total_releases: total }
end
