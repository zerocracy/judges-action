# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/fb'
require 'fbe/overwrite'

def name_of(who)
  n = Fbe.octo.user_name_by_id(who)
  $loog.debug("User ##{who} is actually @#{n}")
  n
rescue Octokit::NotFound => e
  $loog.warn("The user ##{who} is absent in GitHub: #{e.message}")
  'unknown'
end

Fbe.fb.query(
  "(and
    (eq where 'github')
    (exists who)
    (unique who)
    (empty
      (and
        (eq what '#{$judge}')
        (eq who $who)
        (eq where $where))))"
).each do |f|
  n = Fbe.fb.insert
  n.what = $judge
  n.who = f.who
  n.where = f.where
  n.when = Time.now
  n.name = name_of(f.who)
end

Fbe.fb.query(
  "(and
    (eq what 'who-has-name')
    (eq where 'github')
    (exists who)
    (lt when (minus (to_time (env 'TODAY' '#{Time.now.utc.iso8601}')) '5 days')))"
).each do |f|
  Fbe.overwrite(f, 'name', name_of(f.who))
end
