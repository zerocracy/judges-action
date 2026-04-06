# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'

def total_releases_published(fact)
  total =
    Fbe.unmask_repos.sum do |repo|
      owner, name = repo.split('/')
      Fbe.github_graph.total_releases_published(owner, name, fact.since)['releases']
    end
  { total_releases_published: total }
end
