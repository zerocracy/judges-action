# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'

def total_files(_fact)
  files = 0
  TerrainOcto.repos do |repo|
    info = TerrainOcto.safe(repo, 'repository') { Fbe.octo.repository(repo) }
    next if info.nil?
    next if info[:size].nil? || info[:size].zero?
    json = TerrainOcto.safe(repo, 'tree') { Fbe.octo.tree(repo, info[:default_branch], recursive: true) }
    next if json.nil?
    files += json[:tree].count { |item| item[:type] == 'blob' }
  end
  { total_files: files }
end
