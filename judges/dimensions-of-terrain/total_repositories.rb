# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'

def total_repositories(_fact)
  guard = $terrainguard
  total = 0
  guard.eachrepo do |repo|
    json = guard.repository(repo)
    next if json.nil?
    total += 1 unless json[:archived]
  end
  { total_repositories: total }
end
