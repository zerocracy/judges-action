# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'

def total_repositories(_fact)
  total = 0
  Fbe.unmask_repos do |repo|
    total += 1 unless Fbe.octo.repository(repo)[:archived]
  rescue Octokit::NotFound, Octokit::Deprecated => e
    $loog.info("Repository #{repo} not found: #{e.message}")
    next
  rescue Octokit::Forbidden => e
    $loog.warn("[#{$judge}] Access forbidden to #{repo} (transient, will retry next cycle): #{e.class}: #{e.message}")
    next
  end
  { total_repositories: total }
end
