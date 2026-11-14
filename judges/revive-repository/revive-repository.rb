# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/consider'
require 'fbe/fb'
require 'fbe/octo'
require 'fbe/overwrite'
require 'octokit'
require_relative '../../lib/today'

now = Jp.today
recent =
  Set.new(
    Fbe.fb.query(
      "(and (eq stale 'repository') (eq where 'github') (exists repository) (exists repository_revival_checked)
        (gt repository_revival_checked (minus (to_time '#{now.utc.iso8601}') '5 days')))"
    ).each.map(&:repository)
  )
Fbe.consider("(and (eq stale 'repository') (eq where 'github') (unique repository))") do |f|
  next if recent.include?(f.repository)
  json =
    begin
      Fbe.octo.repository(f.repository)
    rescue Octokit::NotFound, Octokit::Deprecated => e
      $loog.info("The repository ##{f.repository} is still stale: #{e.message}")
      Fbe.overwrite(f, 'repository_revival_checked', now)
      recent << f.repository
      next
    rescue Octokit::Forbidden => e
      $loog.warn(
        "[#{$judge}] The repository ##{f.repository} is still stale (access forbidden): #{e.class}: #{e.message}"
      )
      next
    rescue Octokit::ServerError, Faraday::TimeoutError, Faraday::ConnectionFailed => e
      $loog.warn("[#{$judge}] Transient error (will retry next cycle): #{e.class}: #{e.message}")
      next
    end
  $loog.info("The repository ##{f.repository} is not stale, it is #{json[:full_name]}")
  Fbe.fb.query("(and (eq stale 'repository') (eq where 'github') (eq repository #{f.repository}))").each do |f1|
    Fbe.overwrite(f1, { 'stale' => f1['stale'] - ['repository'], 'repository_revival_checked' => [] })
  end
end

Fbe.octo.print_trace!
