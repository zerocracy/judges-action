# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

# Judge that verifies GitHub users still exist and are active.
# Checks GitHub users in the factbase that haven't been updated in the last 2 days,
# attempts to retrieve their nickname, and if the user no longer exists in GitHub,
# mark the entire fact as "stale".
#
# @see ../../lib/nick_of.rb Implementation of the nick retrieval logic
# @see https://github.com/yegor256/fbe/blob/master/lib/fbe/delete.rb Implementation of Fbe.delete

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
  Fbe.fb.query("(and (eq what 'who-has-name') (eq who #{who}))").delete!
  done =
    Fbe.fb.query("(eq who #{who})").each do |n|
      n.stale = "user ##{who}"
    end
  $loog.info("GitHub user ##{who} is gone, deleted it in #{done} facts")
end

Fbe.octo.print_trace!
