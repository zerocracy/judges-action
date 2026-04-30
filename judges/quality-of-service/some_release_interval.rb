# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/github_graph'
require 'fbe/octo'
require 'fbe/unmask_repos'

def some_release_interval(fact)
  dates = []
  Fbe.unmask_repos do |repo|
    owner, name = repo.split('/')
    Fbe.github_graph.releases_in_window(owner, name, fact.since, fact.when).each do |json|
      dates << json['publishedAt']
    end
  end
  dates.sort!
  diffs = (1..(dates.size - 1)).map { |i| dates[i] - dates[i - 1] }
  {
    some_release_interval: diffs
  }
end
