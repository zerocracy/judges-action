# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'

# Average HOC and number of files changed in recent merged PRs
#
# This function is called from the "quality-of-service.rb".
#
# @param [Factbase::Fact] fact The fact just under processing
# @return [Hash] Map with keys as fact attributes and values as integers
def average_hoc_size(fact)
  hocs = []
  files = []
  Fbe.unmask_repos.each do |repo|
    Fbe.octo.search_issues(
      "repo:#{repo} type:pr is:merged closed:>#{fact.since.utc.iso8601[0..9]}"
    )[:items].each do |json|
      Fbe.octo.pull_request(repo, json[:number]).then do |pull|
        hocs << (pull[:additions] + pull[:deletions])
        files << pull[:changed_files]
      end
    end
  end
  {
    average_pull_hoc_size: hocs.empty? ? 0 : hocs.sum.to_f / hocs.size,
    average_pull_files_size: files.empty? ? 0 : files.sum.to_f / files.size
  }
end
