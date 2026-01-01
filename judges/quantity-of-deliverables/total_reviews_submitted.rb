# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
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
  total = 0
  Fbe.unmask_repos.each do |repo|
    owner, name = repo.split('/')
    cursor = nil
    queue = []
    loop do
      json = Fbe.github_graph.pull_requests_with_reviews(owner, name, fact.since, cursor:)
      json['pulls_with_reviews'].each do |p|
        queue.push([p['number'], nil])
      end
      break unless json['has_next_page']
      cursor = json['next_cursor']
    end
    until queue.empty?
      pulls = Fbe.github_graph.pull_request_reviews(owner, name, pulls: queue.shift(10))
      total += pulls.sum { |pull| pull['reviews'].count { |r| r['submitted_at'] > fact.since } }
      pulls.select { _1['reviews_has_next_page'] }.each do |p|
        queue.push([p['number'], p['reviews_next_cursor']])
      end
    end
  end
  { total_reviews_submitted: total }
end
