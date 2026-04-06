# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'

def total_releases(_fact)
  total = 0
  Fbe.unmask_repos do |repo|
    Fbe.octo.releases(repo).each do |_|
      total += 1
    end
  end
  { total_releases: total }
end
