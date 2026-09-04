# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'
require_relative '../../lib/patches/unmask_repos'
require_relative '../../lib/postpone'

def total_files(_fact)
  files = 0
  truncated = false
  Fbe.unmask_repos do |repo|
    info =
      begin
        Fbe.octo.repository(repo)
      rescue Octokit::NotFound, Octokit::Deprecated => e
        $loog.info("Repository #{repo} not found: #{e.message}")
        next
      rescue Octokit::Forbidden => e
        Jp.postpone(repo, e)
      end
    next if info[:size].nil? || info[:size].zero?
    tree =
      begin
        Fbe.octo.tree(repo, info[:default_branch], recursive: true)
      rescue Octokit::NotFound, Octokit::Deprecated => e
        $loog.info("Tree not found for #{repo}@#{info[:default_branch]}: #{e.message}")
        next
      rescue Octokit::Forbidden => e
        Jp.postpone(repo, e)
      end
    if tree[:truncated]
      $loog.info("Tree for #{repo}@#{info[:default_branch]} is truncated, skipping total_files")
      truncated = true
      break
    end
    files += (tree[:tree] || []).count { |item| item[:type] == 'blob' }
  end
  return {} if truncated
  { total_files: files }
end
