# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'

def total_files(_fact)
  files = 0
  Fbe.unmask_repos do |repo|
    info = Fbe.octo.repository(repo)
    next if info[:size].nil? || info[:size].zero?
    Fbe.octo.tree(repo, info[:default_branch], recursive: true).then do |json|
      files += json[:tree].count { |item| item[:type] == 'blob' }
    end
  rescue Octokit::NotFound, Octokit::Deprecated => e
    $loog.info("Repository/tree not found for #{repo}: #{e.message}")
    next
  rescue Octokit::Forbidden => e
    $loog.warn(
      "[#{$judge}] Access forbidden to repository/tree in #{repo} " \
      "(transient, will retry next cycle): #{e.class}: #{e.message}"
    )
    next
  end
  { total_files: files }
end
