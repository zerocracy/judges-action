# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'

def total_stars(_fact)
  stars = 0
  forks = 0
  Fbe.unmask_repos do |repo|
    Fbe.octo.repository(repo).then do |json|
      stars += json[:stargazers_count]
      forks += json[:forks]
    end
  rescue Octokit::NotFound, Octokit::Deprecated => e
    $loog.info("Repository not found for #{repo}: #{e.message}")
    next
  rescue Octokit::Forbidden => e
    $loog.warn(
      "[#{$judge}] Access forbidden to repository #{repo} " \
      "(transient, will retry next cycle): #{e.class}: #{e.message}"
    )
    next
  end
  { total_stars: stars, total_forks: forks }
end
