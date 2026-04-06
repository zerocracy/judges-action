# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'

def some_issue_lifetime(fact)
  ret = {}
  { issue: 'some_issue_lifetime', pr: 'some_pull_lifetime' }.each do |type, prop|
    ages = []
    Fbe.unmask_repos do |repo|
      q = "repo:#{repo} type:#{type} closed:#{fact.since.utc.iso8601}..#{fact.when.utc.iso8601}"
      ages +=
        Fbe.octo.search_issues(q)[:items].map do |json|
          next if json[:closed_at].nil?
          next if json[:created_at].nil?
          json[:closed_at] - json[:created_at]
        end
    end
    ages.compact!
    ret[prop] = ages
  end
  ret
end
