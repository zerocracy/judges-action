# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'elapsed'
require 'fbe/consider'
require 'fbe/fb'
require 'fbe/octo'
require 'logger'
require 'octokit'
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
  nick =
    begin
      Jp.nick_of(f.who)
    rescue Octokit::Forbidden => e
      $loog.warn(
        "[#{$judge}] Access forbidden to user ##{f.who} " \
        "(transient, will retry next cycle): #{e.class}: #{e.message}"
      )
      next
    end
  unless nick.nil?
    $loog.debug("GitHub user @#{nick} (##{f.who}) is alive")
    next
  end
  elapsed($loog, level: Logger::INFO) do
    Fbe.fb.txn do |fbt|
      fbt.query("(and (eq where 'github') (eq what 'who-has-name') (eq who #{f.who}))").delete!
      fbt.query("(and (eq where 'github') (eq who #{f.who}))").each do |n|
        n.stale = 'who'
      end
    end
    throw :"GitHub user ##{f.who} is gone"
  end
end

Fbe.octo.print_trace!
