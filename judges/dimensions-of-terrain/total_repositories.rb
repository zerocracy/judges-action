# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'

def total_repositories(_fact)
  total = 0
  Fbe.unmask_repos do |repo|
    total += 1 unless Fbe.octo.repository(repo)[:archived]
  end
  { total_repositories: total }
end
