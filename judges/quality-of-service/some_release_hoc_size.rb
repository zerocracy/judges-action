# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/github_graph'
require 'fbe/octo'
require 'fbe/unmask_repos'

def some_release_hoc_size(fact)
  grouped = {}
  hocs = []
  commits = []
  Fbe.unmask_repos do |repo|
    owner, name = repo.split('/')
    Fbe.github_graph.releases_in_window(owner, name, fact.since, fact.when).each do |json|
      (grouped[repo] ||= []) << json
    end
  end
  grouped.each do |repo, releases|
    releases.reverse.each_cons(2) do |first, last|
      Fbe.octo.compare(repo, first['tagName'], last['tagName']).then do |json|
        hocs << json[:files].sum { |file| file[:changes] }
        commits << json[:total_commits]
      end
    end
  end
  {
    some_release_hoc_size: hocs,
    some_release_commits_size: commits
  }
end
