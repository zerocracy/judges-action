# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'

def total_repositories(_fact)
  total = 0
  TerrainOcto.repos do |repo|
    json = TerrainOcto.safe(repo, 'repository') { Fbe.octo.repository(repo) }
    next if json.nil?
    total += 1 unless json[:archived]
  end
  { total_repositories: total }
end
