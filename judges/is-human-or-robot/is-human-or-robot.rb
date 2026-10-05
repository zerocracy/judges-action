# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/consider'
require 'fbe/fb'
require 'fbe/issue'
require 'fbe/octo'
require 'fbe/overwrite'
require_relative '../../lib/humans'

@bots = nil

Fbe.consider(
  '(and
    (absent is_human)
    (absent stale)
    (absent tombstone)
    (absent done)
    (eq where "github")
    (exists what)
    (exists who))'
) do |f|
  json =
    begin
      Fbe.octo.user(f.who)
    rescue Octokit::NotFound, Octokit::Deprecated => e
      $loog.info("GitHub user ##{f.who} is not found: #{e.message}")
      f.stale = 'who'
      next
    rescue Octokit::Forbidden => e
      $loog.warn(
        "[#{$judge}] GitHub user ##{f.who} is not accessible " \
        "(transient, will retry next cycle): #{e.class}: #{e.message}"
      )
      next
    end
  type = json[:type]
  location = "#{f.what} at #{Fbe.issue(f) if f['issue']}"
  @bots ||= Jp.bots
  if type == 'Bot' || @bots.include?(json[:login])
    f.is_human = 0
    $loog.info("GitHub user ##{f.who} (@#{json[:login]}) is actually a bot, in #{location}")
  else
    f.is_human = 1
    $loog.info("GitHub user ##{f.who} (@#{json[:login]}) is not a bot, in #{location}")
  end
end

Jp.bots.each do |login|
  Fbe.fb.query(
    "(and (eq what 'who-has-name') (eq where 'github') (eq name '#{login}') (exists who))"
  ).each.to_a.each do |n|
    Fbe.fb.query("(and (eq where 'github') (eq who #{n.who}) (eq is_human 1))").each.to_a.each do |f|
      Fbe.overwrite(f, 'is_human', 0)
      $loog.info("GitHub user ##{n.who} (@#{login}) is configured as a bot, fact ##{f._id} is re-classified")
    end
  end
end

Fbe.octo.print_trace!
