# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'
require_relative '../../lib/qos_search'

def some_issue_lifetime(fact)
  ret = {}
  { issue: 'some_issue_lifetime', pr: 'some_pull_lifetime' }.each do |type, prop|
    ages = []
    lost = false
    Fbe.unmask_repos do |repo|
      if Fbe.octo.off_quota?
        lost = true
        break
      end
      query = "repo:#{repo} type:#{type} closed:#{fact.since.utc.iso8601}..#{fact.when.utc.iso8601}"
      found = Jp.qosearch(query)
      if found.nil?
        lost = true
        break
      end
      Jp.capped?(found, query)
      ages +=
        found[:items].map do |json|
          next if json[:closed_at].nil?
          next if json[:created_at].nil?
          json[:closed_at] - json[:created_at]
        end
    end
    next if lost
    ages.compact!
    ret[prop] = ages
  end
  ret
end
