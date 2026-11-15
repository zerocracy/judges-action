# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/consider'
require 'fbe/fb'
require 'fbe/octo'
require 'fbe/overwrite'
require_relative '../../lib/today'

now = Jp.today
recent =
  Set.new(
    Fbe.fb.query(
      "(and (eq stale 'who') (eq where 'github') (exists who) (exists user_revival_checked)
        (gt user_revival_checked (minus (to_time '#{now.utc.iso8601}') '5 days')))"
    ).each.map(&:who)
  )
Fbe.consider("(and (eq stale 'who') (eq where 'github') (unique who))") do |f|
  next if recent.include?(f.who)
  json =
    begin
      Fbe.octo.user(f.who)
    rescue Octokit::NotFound, Octokit::Deprecated => e
      $loog.info("The user ##{f.who} is still stale: #{e.message}")
      Fbe.overwrite(f, 'user_revival_checked', now)
      recent << f.who
      next
    rescue Octokit::Forbidden => e
      $loog.warn("[#{$judge}] The user ##{f.who} is still stale (access forbidden): #{e.class}: #{e.message}")
      next
    end
  $loog.info("The user ##{f.who} is not stale, it is @#{json[:login]}")
  Fbe.fb.query("(and (eq stale 'who') (eq who #{f.who}))").each do |f1|
    Fbe.overwrite(f1, { 'stale' => f1['stale'] - ['who'], 'user_revival_checked' => [] })
  end
end

Fbe.octo.print_trace!
