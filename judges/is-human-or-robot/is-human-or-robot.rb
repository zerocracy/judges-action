# frozen_string_literal: true

require 'fbe/consider'
# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/issue'
require 'fbe/octo'

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
      $loog.warn("[#{$judge}] GitHub user ##{f.who} is not accessible: #{e.class}: #{e.message}")
      f.stale = 'who'
      next
    end
  type = json[:type]
  location = "#{f.what} at #{Fbe.issue(f) if f['issue']}"
  @bots ||=
    if $options.respond_to?(:bots) && !$options.bots.nil? && !$options.bots.empty?
      names = $options.bots.split(',').map(&:strip)
      names.reject!(&:empty?)
      names
    else
      []
    end
  if type == 'Bot' || @bots.include?(json[:login])
    f.is_human = 0
    $loog.info("GitHub user ##{f.who} (@#{json[:login]}) is actually a bot, in #{location}")
  else
    f.is_human = 1
    $loog.info("GitHub user ##{f.who} (@#{json[:login]}) is not a bot, in #{location}")
  end
end

Fbe.octo.print_trace!
