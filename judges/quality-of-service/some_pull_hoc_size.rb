# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'

def some_pull_hoc_size(fact)
  hocs = []
  files = []
  Fbe.unmask_repos do |repo|
    Fbe.octo.search_issues(
      "repo:#{repo} type:pr is:merged closed:#{fact.since.utc.iso8601}..#{fact.when.utc.iso8601}"
    )[:items].each do |json|
      Fbe.octo.pull_request(repo, json[:number]).then do |pull|
        hocs << (pull[:additions] + pull[:deletions])
        files << pull[:changed_files]
      end
    end
  end
  {
    some_pull_hoc_size: hocs,
    some_pull_files_size: files
  }
end
