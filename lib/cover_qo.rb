# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/fb'
require 'fbe/if_absent'
require_relative 'jp'

# Make sure the entire timeline is covered by Qo facts.
def Jp.cover_qo(days, judge: $judge)
  last = Fbe.fb.query(
    "(eq when
       (agg
         (eq what '#{judge}')
         (max when)))"
  ).each.first
  if last.nil?
    Fbe.fb.insert.then do |n|
      n.what = judge
      n.when = Time.now.utc
      n.since = n.when - (days * 24 * 60 * 60)
    end
  elsif last.when < Time.now.utc - (days * 24 * 60 * 60)
    Fbe.if_absent do |n|
      n.what = judge
      n.since = last.when
      n.when = n.since + (days * 24 * 60 * 60)
    end
  end
  prev = nil
  Fbe.consider("(and (eq what '#{judge}') (exists since) (exists when))") do |f|
    if !prev.nil? && (f.since - prev.when).positive?
      Fbe.if_absent do |n|
        n.what = judge
        n.since = prev.when
        n.when = f.since
      end
    end
    prev = f
  end
end
