# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/delete'
require 'fbe/fb'
require 'fbe/octo'
require_relative '../../lib/nick_of'

users = Fbe.fb.query(
  "(and
    (eq where 'github')
    (eq what 'who-has-name')
    (exists who)
    (lt when (minus (to_time (env 'TODAY' '#{Time.now.utc.iso8601}')) '2 days')))"
).each.map(&:who).uniq

users.each do |who|
  nick = Jp.nick_of(who)
  unless nick.nil?
    $loog.debug("GitHub user @#{nick} (##{who}) is alive")
    next
  end
  done =
    Fbe.fb.query("(eq who #{who})").each do |n|
      Fbe.delete(n, 'who')
    end
  $loog.info("GitHub user ##{who} is gone, deleted it in #{done} facts")
end
