# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'
require_relative '../../lib/patches/unmask_repos'

def total_stars(_fact)
  stars = 0
  forks = 0
  skipped = false
  Fbe.unmask_repos do |repo|
    json =
      begin
        Fbe.octo.repository(repo)
      rescue Octokit::NotFound, Octokit::Deprecated => e
        $loog.info("Repository #{repo} not found: #{e.message}")
        next
      rescue Octokit::TooManyRequests => e
        $loog.warn("[#{$judge}] API rate limit exhausted, stopping the scan: #{e.class}: #{e.message}")
        break
      rescue Octokit::Forbidden => e
        $loog.warn(
          "[#{$judge}] Access forbidden to #{repo} " \
          "(transient, will retry next cycle): #{e.class}: #{e.message}"
        )
        skipped = true
        break
      end
    stars += json[:stargazers_count] || 0
    forks += json[:forks] || 0
  end
  return {} if skipped
  { total_stars: stars, total_forks: forks }
end
