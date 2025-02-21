# frozen_string_literal: true

# MIT License
#
# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'

# Number of commits pushed and their hits-of-code:
#
# This function is called from the "quantity-of-deliverables.rb".
#
# @param [Factbase::Fact] fact The fact just under processing
# @return [Hash] Map with keys as fact attributes and values as integers
def total_commits_pushed(fact)
  commits = 0
  hoc = 0
  Fbe.unmask_repos.each do |repo|
    next if Fbe.octo.repository(repo)[:size].zero?
    Fbe.octo.commits_since(repo, fact.since).each do |json|
      commits += 1
      hoc += Fbe.octo.commit(repo, json[:sha])[:stats][:total]
    end
  end
  {
    total_commits_pushed: commits,
    total_hoc_committed: hoc
  }
end
