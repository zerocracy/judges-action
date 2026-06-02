# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'

def total_releases(_fact)
  guard = $terrainguard
  total = 0
  guard.eachrepo do |repo|
    releases = guard.releases(repo)
    next unless releases.is_a?(Array)
    releases.each do |_|
      total += 1
    end
  end
  { total_releases: total }
end
