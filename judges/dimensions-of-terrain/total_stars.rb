# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'

def total_stars(_fact)
  guard = $terrainguard
  stars = 0
  forks = 0
  guard.eachrepo do |repo|
    json = guard.repository(repo)
    next if json.nil?
    stars += json[:stargazers_count]
    forks += json[:forks]
  end
  { total_stars: stars, total_forks: forks }
end
