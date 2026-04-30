# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/github_graph'
require 'fbe/octo'
require 'fbe/unmask_repos'

def total_releases(_fact)
  total = 0
  Fbe.unmask_repos do |repo|
    owner, name = repo.split('/')
    total += Fbe.github_graph.releases_count(owner, name)['releases']
  end
  { total_releases: total }
end
