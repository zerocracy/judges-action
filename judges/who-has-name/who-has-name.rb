# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/delete'
require 'fbe/fb'
require 'fbe/octo'
require 'fbe/overwrite'

# Gets nick name of GitHub user, or NIL if user not found.
# @param [String] who The ID of GitHub user
# @return [String] The nick name
def name_of(who)
  n = Fbe.octo.user_name_by_id(who)
  $loog.debug("User ##{who} is actually @#{n}")
  n
rescue Octokit::NotFound => e
  $loog.warn("The user ##{who} is absent in GitHub: #{e.message}")
  nil
end

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
  nick = name_of(f.who)
  if nick.nil?
    Fbe.delete(f, 'who')
  else
    n = Fbe.fb.insert
    n.what = $judge
    n.who = f.who
    n.where = f.where
    n.when = Time.now
    n.name = nick
  end
end

Fbe.fb.query(
  "(and
    (eq what 'who-has-name')
    (eq where 'github')
    (exists who)
    (lt when (minus (to_time (env 'TODAY' '#{Time.now.utc.iso8601}')) '5 days')))"
).each do |f|
  nick = name_of(f.who)
  if nick.nil?
    Fbe.delete(f, 'who')
  else
    Fbe.overwrite(f, 'name', nick)
  end
end
