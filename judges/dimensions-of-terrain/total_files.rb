# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'

def total_files(_fact)
  files = 0
  Fbe.unmask_repos do |repo|
    info =
      begin
        Fbe.octo.repository(repo)
      rescue Octokit::NotFound, Octokit::Deprecated => e
        $loog.info("Repository #{repo} not found: #{e.message}")
        next
      rescue Octokit::Forbidden => e
        $loog.warn(
          "[#{$judge}] Access forbidden to #{repo} " \
          "(transient, will retry next cycle): #{e.class}: #{e.message}"
        )
        next
      end
    next if info[:size].nil? || info[:size].zero?
    tree =
      begin
        Fbe.octo.tree(repo, info[:default_branch], recursive: true)
      rescue Octokit::NotFound, Octokit::Deprecated => e
        $loog.info("Tree not found for #{repo}@#{info[:default_branch]}: #{e.message}")
        next
      rescue Octokit::Forbidden => e
        $loog.warn(
          "[#{$judge}] Access forbidden to tree for #{repo} " \
          "(transient, will retry next cycle): #{e.class}: #{e.message}"
        )
        next
      end
    files += tree[:tree].count { |item| item[:type] == 'blob' }
  end
  { total_files: files }
end
