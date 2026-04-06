# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'

def total_contributors(_fact)
  contributors = Set.new
  Fbe.unmask_repos do |repo|
    next if Fbe.octo.repository(repo)[:size].zero?
    Fbe.octo.contributors(repo).each do |contributor|
      contributors << contributor[:id]
    end
  end
  { total_contributors: contributors.count }
end
