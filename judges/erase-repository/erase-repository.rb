# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

# Judge that removes references to deleted GitHub repositories from the factbase.
# Checks all records containing repository references against the GitHub API,
# and if a repository no longer exists (returns 404), removes the repository reference
# from the factbase record to maintain data integrity.

require 'elapsed'
require 'fbe/octo'
require 'fbe/consider'
require 'logger'

good = {}

Fbe.fb.query('(and (eq where "github") (exists repository) (absent stale))').each do |f|
  next if Fbe.octo.off_quota?
  r = f.repository
  next unless good[r].nil?
  elapsed($loog, level: Logger::INFO) do
    json = Fbe.octo.repository(r)
    good[r] = true
    throw :"GitHub repository ##{r} is found: #{json[:full_name]}"
  rescue Octokit::NotFound
    good[r] = false
    throw :"GitHub repository ##{r} is not found"
  end
end

good.each do |repo, ok|
  next if ok
  Fbe.fb.query("(and (eq where 'github') (eq repository #{repo}) (absent stale))").each do |f|
    f.stale = 'repository'
  end
end

Fbe.octo.print_trace!
