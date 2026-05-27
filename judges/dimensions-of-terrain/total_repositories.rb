# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'

def total_repositories(_fact)
  guard = $terrainguard
  total = 0
  guard.eachrepo do |_repo|
    total += 1
  end
  { total_repositories: total }
end
