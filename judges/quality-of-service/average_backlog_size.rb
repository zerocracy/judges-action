# frozen_string_literal: true

# MIT License
#
# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'

# Average issues
#
# This function is called from the "quality-of-service.rb".
#
# @param [Factbase::Fact] fact The fact just under processing
# @return [Hash] Map with keys as fact attributes and values as integers
def average_backlog_size(fact)
  issues = []
  Fbe.unmask_repos.each do |repo|
    (fact.since.utc.to_date..Time.now.utc.to_date).each do |date|
      count = 0
      Fbe.octo.search_issues(
        "repo:#{repo} type:issue created:#{fact.since.utc.to_date.iso8601[0..9]}..#{date.iso8601[0..9]}"
      )[:items].each do |item|
        count += 1 if item[:closed_at].nil? || item[:closed_at].utc.to_date >= date
      end
      issues << count
    end
  end
  { average_backlog_size: issues.empty? ? 0 : issues.inject(&:+).to_f / issues.size }
end
