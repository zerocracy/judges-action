# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/fb'
require 'fbe/if_absent'
require_relative 'jp'

# Make sure the entire timeline is covered by Qo facts.
def Jp.cover_qo(days, judge: $judge, loog: $loog, today: Time.parse(ENV['TODAY'] || Time.now.utc.iso8601))
  slice = days * 24 * 60 * 60
  facts = Fbe.fb.query("(and (eq what '#{judge}') (exists since) (exists when))").each.to_a.sort_by(&:since)
  last = facts.map(&:when).max
  if last.nil?
    Fbe.fb.insert.then do |n|
      n.what = judge
      n.when = today
      n.since = n.when - slice
      loog.info("First #{judge} inserted: #{n.since.utc.iso8601}..#{n.when.utc.iso8601}")
    end
    return
  end
  if last && last < today - slice
    Fbe.fb.insert.then do |n|
      n.what = judge
      n.since = last
      n.when = today
      loog.info("Fresh #{judge} added: #{n.since.utc.iso8601}..#{n.when.utc.iso8601}")
      facts << n
    end
  end
  prev = facts.min_by(&:since)
  gaps = []
  facts.each do |f|
    gaps << { since: prev.when, when: f.since } if f.since > prev.when
    prev = f
  end
  large = gaps.reject { |g| g[:when] - g[:since] < slice }
  large.reject { |g| facts.find { |f| g[:since] < f.when && g[:when] > f.since } }.each do |g|
    Fbe.fb.insert.then do |n|
      n.what = judge
      n.since = g[:since]
      n.when = g[:when]
      loog.info("Missing gap of #{judge} filled up: #{n.since.utc.iso8601}..#{n.when.utc.iso8601}")
    end
  end
end
