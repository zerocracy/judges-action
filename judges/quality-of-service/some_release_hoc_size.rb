# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'
require_relative '../../lib/in_window_releases'

def some_release_hoc_size(fact)
  grouped = {}
  hocs = []
  commits = []
  Fbe.unmask_repos do |repo|
    Jp.in_window_releases(repo, fact.since, fact.when) do |json|
      (grouped[repo] ||= []) << json
    end
  end
  grouped.each do |repo, releases|
    releases.reverse.each_cons(2) do |first, last|
      Fbe.octo.compare(repo, first[:tag_name], last[:tag_name]).then do |json|
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
