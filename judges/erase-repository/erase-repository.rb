# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

# Judge that removes references to deleted GitHub repositories from the factbase.
# Checks all records containing repository references against the GitHub API,
# and if a repository no longer exists (returns 404), removes the repository reference
# from the factbase record to maintain data integrity.
#
# @see https://github.com/yegor256/fbe/blob/master/lib/fbe/conclude.rb Implementation of Fbe.conclude
# @see https://github.com/yegor256/fbe/blob/master/lib/fbe/delete.rb Implementation of Fbe.delete

require 'fbe/octo'
require 'fbe/conclude'

Fbe.conclude do
  quota_aware
  on '(and (eq where "github") (exists repository) (not (exists stale)))'
  consider do |f|
    Fbe.octo.repository(f.repository)
  rescue Octokit::NotFound
    $loog.info("GitHub repository ##{f.repository} is not found")
    f.stale = Time.now
  end
end

Fbe.octo.print_trace!
