# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'
require_relative '../../lib/patches/unmask_repos'
require_relative '../../lib/postpone'

def total_repositories(_fact)
  total = 0
  Fbe.unmask_repos do |repo|
    total += 1 unless Fbe.octo.repository(repo)[:archived]
  rescue Octokit::NotFound, Octokit::Deprecated => e
    $loog.info("Repository #{repo} not found: #{e.message}")
    next
  rescue Octokit::Forbidden => e
    Jp.postpone(repo, e)
  end
  { total_repositories: total }
end
