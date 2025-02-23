# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'

# Total number of releases published in all repositories from since
#
# This function is called from the "quantity-of-deliverables.rb".
#
# @param [Factbase::Fact] fact The fact just under processing
# @return [Hash] Map with keys as fact attributes and values as integers
def total_releases_published(fact)
  total =
    Fbe.unmask_repos.sum do |repo|
      Fbe.octo.releases(repo).count do |json|
        !json[:draft] && json[:published_at] && json[:published_at] > fact.since
      end
    end
  { total_releases_published: total }
end
