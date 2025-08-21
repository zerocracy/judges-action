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

require 'fbe/conclude'
require 'fbe/delete'
require 'fbe/fb'
require 'fbe/octo'
require 'fbe/overwrite'
require_relative '../../lib/nick_of'

alive = []

Fbe.conclude do
  quota_aware
  on "(and
    (not (exists stale))
    (exists what)
    (exists who)
    (eq where 'github')
    (unique who)
    (empty (and
      (eq who $who)
      (eq what '#{$judge}')
      (eq where $where))))"
  follow 'who where'
  draw do |n, f|
    nick = Jp.nick_of(f.who)
    if nick.nil?
      f.stale = "user ##{f.who}"
      throw :rollback
    end
    alive << f.who
    n.name = nick
    n.what = $judge
    n.details = "We found out that the user ##{f.who} is known in GitHub as @#{nick}."
  end
end

Fbe.conclude do
  quota_aware
  on "(and
    (eq what 'who-has-name')
    (lt when (minus (to_time (env 'TODAY' '#{Time.now.utc.iso8601}')) '5 days'))
    (not (exists stale))
    (exists who)
    (eq where 'github'))"
  consider do |f|
    nick = Jp.nick_of(f.who)
    if nick.nil?
      f.stale = "user ##{f.who}"
      next
    end
    alive << f.who
    Fbe.overwrite(f, 'name', nick)
  end
end

Fbe.fb.query(
  "(and
    (exists _id)
    (exists stale)
    (exists who)
    (or #{alive.uniq.map { |u| "(eq who #{u})" }.join}))"
).each do |f|
  next unless f.stale == "user ##{f.who}"
  Fbe.delete(f, 'stale')
end

Fbe.octo.print_trace!
