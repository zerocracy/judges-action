# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'
require_relative '../../lib/patches/unmask_repos'
require_relative '../../lib/postpone'

def total_contributors(_fact)
  contributors = Set.new
  Fbe.unmask_repos do |repo|
    json =
      begin
        Fbe.octo.repository(repo)
      rescue Octokit::NotFound, Octokit::Deprecated => e
        $loog.info("Repository #{repo} not found: #{e.message}")
        next
      rescue Octokit::Forbidden => e
        Jp.postpone(repo, e)
      end
    next if json[:size].nil? || json[:size].zero?
    list =
      begin
        Fbe.octo.contributors(repo)
      rescue Octokit::NotFound, Octokit::Deprecated => e
        $loog.info("Contributors not found for #{repo}: #{e.message}")
        next
      rescue Octokit::Forbidden => e
        Jp.postpone(repo, e)
      end
    next unless list.is_a?(Array)
    list.each do |contributor|
      contributors << contributor[:id]
    end
  rescue Octokit::NotFound, Octokit::Deprecated => e
    $loog.info("Repository/contributors info not found for #{repo}: #{e.message}")
    next
  rescue Octokit::Forbidden => e
    Jp.postpone(repo, e)
  end
  { total_contributors: contributors.count }
end
