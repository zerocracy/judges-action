# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

# Judge that identifies whether a GitHub user is a human or a bot.
# Examines GitHub users found in the factbase, determines if they are
# humans or bots based on GitHub user type and a configurable bot list
# from options. Records the result in the factbase.
#
# @see https://github.com/yegor256/fbe/blob/master/lib/fbe/conclude.rb Implementation of Fbe.conclude
# @note Sets is_human=1 for humans and is_human=0 for bots
# @note Configurable bot usernames can be provided via $options.bots (comma-separated)

require 'fbe/octo'
require 'fbe/consider'

@configured_bots = nil

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
    end
  type = json[:type]
  location = "#{f.what} at #{Fbe.issue(f) if f['issue']}"
  @configured_bots ||=
    if $options.respond_to?(:bots) && !$options.bots.nil? && !$options.bots.empty?
      $options.bots.split(',').map(&:strip).reject(&:empty?)
    else
      []
    end
  if type == 'Bot' || @configured_bots.include?(json[:login])
    f.is_human = 0
    $loog.info("GitHub user ##{f.who} (@#{json[:login]}) is actually a bot, in #{location}")
  else
    f.is_human = 1
    $loog.info("GitHub user ##{f.who} (@#{json[:login]}) is not a bot, in #{location}")
  end
end

Fbe.octo.print_trace!
