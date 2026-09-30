# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/fb'
require 'fbe/if_absent'
require_relative 'jp'
require_relative 'today'

def Jp.cover_qo(days, judge: $judge, loog: $loog, today: nil)
  today ||= Jp.today
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
  start = last
  while start + slice < today
    Fbe.fb.insert.then do |n|
      n.what = judge
      n.since = start
      n.when = start + slice
      loog.info("Fresh #{judge} added: #{n.since.utc.iso8601}..#{n.when.utc.iso8601}")
      facts << n
    end
    start += slice
  end
  prev = facts.min_by(&:since)
  gaps = []
  facts.each do |f|
    gaps << { since: prev.when, when: f.since } if f.since > prev.when
    prev = f
  end
  small, large = gaps.partition { |g| g[:when] - g[:since] < slice }
  small.each do |g|
    loog.info(
      "Gap of #{judge} left unmeasured, it is shorter than one window of #{days} days: " \
      "#{g[:since].utc.iso8601}..#{g[:when].utc.iso8601}"
    )
  end
  large.reject { |g| facts.find { |f| g[:since] < f.when && g[:when] > f.since } }.each do |g|
    start = g[:since]
    while start + slice <= g[:when]
      Fbe.fb.insert.then do |n|
        n.what = judge
        n.since = start
        n.when = start + slice
        loog.info("Missing gap of #{judge} filled up: #{n.since.utc.iso8601}..#{n.when.utc.iso8601}")
      end
      start += slice
    end
  end
end
