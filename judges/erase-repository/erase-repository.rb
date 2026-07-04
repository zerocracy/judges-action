# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'elapsed'
require 'fbe/consider'
require 'fbe/octo'
require 'logger'
require 'octokit'

good = {}

Fbe.fb.query('(and (eq where "github") (exists repository) (absent stale))').each do |f|
  next if Fbe.octo.off_quota?
  r = f.repository
  next unless good[r].nil?
  elapsed($loog, level: Logger::INFO) do
    json = Fbe.octo.repository(r)
    good[r] = true
    throw(:"GitHub repository ##{r} is found: #{json[:full_name]}")
  rescue Octokit::NotFound, Octokit::Deprecated, Octokit::TooManyRequests => e
    good[r] = false
    throw(:"GitHub repository ##{r} is not found: #{e.message}")
  rescue Octokit::Forbidden => e
    $loog.warn(
      "[#{$judge}] Access forbidden to GitHub repository ##{r} " \
      "(transient, will retry next cycle): #{e.class}: #{e.message}"
    )
  end
end

good.each do |repo, ok|
  next if ok
  Fbe.fb.query("(and (eq where 'github') (eq repository #{repo}) (absent stale))").each do |f|
    f.stale = 'repository'
  end
end

Fbe.octo.print_trace!
