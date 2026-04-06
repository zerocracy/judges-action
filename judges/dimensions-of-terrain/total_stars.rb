# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'

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
