# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/consider'
require 'fbe/octo'
require_relative '../../lib/humans'

@bots = nil
users =
  Hash.new do |cache, id|
    cache[id] =
      begin
        Fbe.octo.user(id)
      rescue Octokit::NotFound, Octokit::Deprecated => e
        $loog.info("GitHub user ##{id} is not found: #{e.message}")
        :missing
      rescue Octokit::Forbidden => e
        $loog.warn(
          "[#{$judge}] GitHub user ##{id} is not accessible " \
          "(transient, will retry next cycle): #{e.class}: #{e.message}"
        )
        :forbidden
      end
  end

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
  json = users[f.who]
  if json == :missing
    f.stale = 'who'
    next
  end
  next if json == :forbidden
  type = json[:type]
  location = f['issue'] ? "#{f.what} at #{f.repository}##{f.issue}" : f.what.to_s
  @bots ||= Jp.bots
  if type == 'Bot' || @bots.include?(json[:login])
    f.is_human = 0
    $loog.info("GitHub user ##{f.who} (@#{json[:login]}) is actually a bot, in #{location}")
  else
    f.is_human = 1
    $loog.info("GitHub user ##{f.who} (@#{json[:login]}) is not a bot, in #{location}")
  end
end

Fbe.octo.print_trace!
