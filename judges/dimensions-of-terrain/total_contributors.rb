# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'

def total_contributors(_fact)
  contributors = Set.new
  TerrainOcto.repos do |repo|
    json = TerrainOcto.safe(repo, 'repository') { Fbe.octo.repository(repo) }
    next if json.nil?
    next if json[:size].nil? || json[:size].zero?
    list = TerrainOcto.safe(repo, 'contributors') { Fbe.octo.contributors(repo) }
    next unless list.is_a?(Array)
    list.each do |contributor|
      contributors << contributor[:id]
    end
  end
  { total_contributors: contributors.count }
end
