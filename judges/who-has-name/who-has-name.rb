# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

# Judge that retrieves GitHub usernames (nicks) for users in the factbase.
# Finds users in the factbase who don't have a name recorded yet,
# retrieves their GitHub nickname, and stores it in the factbase.
# It also updates nicknames for existing records that are more than 5 days old.
#
# @see ../../lib/nick_of.rb Implementation of the nick retrieval logic
# @note This judge runs periodically to ensure all users have up-to-date nicknames recorded

require 'fbe/delete'
require 'fbe/fb'
require 'fbe/octo'
require 'fbe/overwrite'
require_relative '../../lib/nick_of'

Fbe.fb.query(
  "(and
    (eq where 'github')
    (exists who)
    (unique who)
    (empty (and
      (eq who $who)
      (eq what '#{$judge}')
      (eq where $where))))"
).each do |f|
  nick = Jp.nick_of(f.who)
  next if nick.nil?
  n = Fbe.fb.insert
  n.what = $judge
  n.who = f.who
  n.where = f.where
  n.when = Time.now
  n.name = nick
end

Fbe.fb.query(
  "(and
    (eq what 'who-has-name')
    (eq where 'github')
    (exists who)
    (lt when (minus (to_time (env 'TODAY' '#{Time.now.utc.iso8601}')) '5 days')))"
).each do |f|
  nick = Jp.nick_of(f.who)
  next if nick.nil?
  Fbe.overwrite(f, 'name', nick)
end
