# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'elapsed'
require 'fbe/consider'
require 'fbe/fb'
require 'fbe/octo'
require 'logger'
require_relative '../../lib/nick_of'

seen = []

Fbe.consider(
  "(and
    (eq what 'who-has-name')
    (lt when (minus (to_time (env 'TODAY' '#{Time.now.utc.iso8601}')) '2 days'))
    (absent stale)
    (absent tombstone)
    (absent done)
    (exists who)
    (eq where 'github'))"
) do |f|
  next if seen.include?(f.who)

  seen << f.who
  nick = Jp.nick_of(f.who)
  unless nick.nil?
    $loog.debug("GitHub user @#{nick} (##{f.who}) is alive")
    next
  end
  elapsed($loog, level: Logger::INFO) do
    Fbe.fb.query("(and (eq where 'github') (eq what 'who-has-name') (eq who #{f.who}))").delete!
    done =
      Fbe.fb.query("(and (eq where 'github') (eq who #{f.who}))").each do |n|
        n.stale = 'who'
      end
    throw :"GitHub user ##{f.who} is gone, marked #{done} facts as stale"
  end
end

Fbe.octo.print_trace!
