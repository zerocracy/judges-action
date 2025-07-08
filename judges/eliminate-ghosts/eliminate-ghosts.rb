# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

# Judge that removes references to deleted GitHub users from the factbase.
# Checks all records with GitHub user references against the GitHub API,
# and if a user no longer exists (returns 404), removes the user reference
# from the factbase record to maintain data integrity.

require 'elapsed'
require 'fbe/octo'
require 'fbe/conclude'
require_relative '../../lib/nick_of'

good = Set.new
bad = Set.new

Fbe.conclude do
  quota_aware
  on '(and (eq where "github") (exists who) (unique who) (not (exists stale)))'
  consider do |f|
    next if good.include?(f.who)
    elapsed($loog) do
      nick = Jp.nick_of(f.who)
      if nick.nil? || bad.include?(f.who)
        f.stale = "user ##{f.who}"
        bad.add(f.who)
        throw :"GitHub user ##{f.who} (##{bad.size}) is not found"
      else
        good.add(f.who)
        throw :"GitHub user ##{f.who} (##{good.size}) is good: @#{nick}"
      end
    end
  end
end

Fbe.octo.print_trace!
