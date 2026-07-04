# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'
require_relative '../../lib/qos_search'

def some_pull_hoc_size(fact)
  hocs = []
  files = []
  Fbe.unmask_repos do |repo|
    return {} if Fbe.octo.off_quota?
    found = Jp.qosearch("repo:#{repo} type:pr is:merged closed:#{fact.since.utc.iso8601}..#{fact.when.utc.iso8601}")
    return {} if found.nil?
    found[:items].each do |json|
      pull =
        begin
          Fbe.octo.pull_request(repo, json[:number])
        rescue Octokit::NotFound, Octokit::Deprecated, Octokit::TooManyRequests => e
          $loog.info("Pull request ##{json[:number]} not found in #{repo}: #{e.message}")
          next
        rescue Octokit::Forbidden => e
          $loog.warn(
            "[#{$judge}] Access forbidden to pull request ##{json[:number]} in #{repo} " \
            "(transient, will retry next cycle): #{e.class}: #{e.message}"
          )
          next
        end
      hocs << (pull[:additions] + pull[:deletions])
      files << pull[:changed_files]
    end
  end
  {
    some_pull_hoc_size: hocs,
    some_pull_files_size: files
  }
end
