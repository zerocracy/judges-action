# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

# Judge that removes references to deleted GitHub users from the factbase.
# Checks all records with GitHub user references against the GitHub API,
# and if a user no longer exists (returns 404), removes the user reference
# from the factbase record to maintain data integrity.

require 'elapsed'
require 'fbe/octo'
require 'fbe/consider'
require 'logger'
require_relative '../../lib/nick_of'

good = Set.new

Fbe.consider('(and (absent stale) (eq where "github") (exists who))') do |f|
  next if good.include?(f.who)
  elapsed($loog, level: Logger::INFO) do
    nick = Jp.nick_of(f.who)
    if nick.nil?
      f.stale = 'who'
      throw :"GitHub user ##{f.who} is not found (stale)"
    else
      good.add(f.who)
      throw :"GitHub user ##{f.who} (##{good.size}) is good: @#{nick}"
    end
  end
end

Fbe.consider('(and (eq where "github") (exists who) (unique who) (eq stale "who"))') do |f|
  Fbe.consider("(and (eq who #{f.who}) (not (eq stale 'who')) (eq where 'github'))") do |ff|
    ff.stale = 'who'
  end
end

Fbe.octo.print_trace!
