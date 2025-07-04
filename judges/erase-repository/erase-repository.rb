# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

# Judge that removes references to deleted GitHub repositories from the factbase.
# Checks all records containing repository references against the GitHub API,
# and if a repository no longer exists (returns 404), removes the repository reference
# from the factbase record to maintain data integrity.

require 'fbe/octo'
require 'fbe/conclude'

good = {}

Fbe.conclude do
  quota_aware
  on '(and (eq where "github") (exists repository) (not (exists stale)))'
  consider do |f|
    r = f.repository
    if good[r].nil?
      begin
        json = Fbe.octo.repository(r)
        good[r] = true
        $loog.info("GitHub repository ##{r} is found: #{json[:full_name]}")
      rescue Octokit::NotFound
        good[r] = false
        $loog.info("GitHub repository ##{r} is not found")
      end
    end
    f.stale = "repo ##{r}" unless good[r]
  end
end

Fbe.octo.print_trace!
