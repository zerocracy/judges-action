# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/unmask_repos'
require_relative '../../lib/patches/unmask_repos'

def total_repositories(_fact)
  total = 0
  Fbe.unmask_repos { total += 1 }
  { total_repositories: total }
end
