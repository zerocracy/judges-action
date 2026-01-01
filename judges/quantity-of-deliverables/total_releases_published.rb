# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'

# Calculates the total number of releases published across all monitored GitHub repositories.
# This function counts only non-draft releases that were published after the specified 'since' date
# in the fact object, allowing for time-based metrics collection.
#
# This function is called from the "quantity-of-deliverables.rb" using the incremate
# helper to collect this specific metric as part of deliverables quantity analysis.
#
# @param [Factbase::Fact] fact The fact object containing the 'since' timestamp
# @return [Hash] Map with total_releases_published count as key-value pair
# @see ../quantity-of-deliverables.rb Main judge that calls this function
def total_releases_published(fact)
  total =
    Fbe.unmask_repos.sum do |repo|
      owner, name = repo.split('/')
      Fbe.github_graph.total_releases_published(owner, name, fact.since)['releases']
    end
  { total_releases_published: total }
end
