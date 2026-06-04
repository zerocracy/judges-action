# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'

def total_stars(_fact)
  stars = 0
  forks = 0
  Fbe.unmask_repos do |repo|
    json =
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
    stars += json[:stargazers_count]
    forks += json[:forks]
  end
  { total_stars: stars, total_forks: forks }
end
