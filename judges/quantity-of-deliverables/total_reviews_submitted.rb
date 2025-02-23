# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'

# Total number of code reviews in all repositories from since
#
# This function is called from the "quantity-of-deliverables.rb".
#
# @param [Factbase::Fact] fact The fact just under processing
# @return [Hash] Map with keys as fact attributes and values as integers
def total_reviews_submitted(fact)
  total =
    Fbe.unmask_repos.sum do |repo|
      Fbe.octo.pull_requests(repo, state: 'all').sum do |pr|
        Fbe.octo.pull_request_reviews(repo, pr[:number]).count do |review|
          review[:submitted_at] && review[:submitted_at] > fact.since
        end
      end
    end
  { total_reviews_submitted: total }
end
