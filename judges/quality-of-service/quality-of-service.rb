# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

# Judge that fetches various quality metrics for GitHub repositories.
# Regularly collects quality of service metrics such as issue lifetime,
# build success rate, review time, pull request HoC size, release interval,
# backlog size, triage time, and other quality indicators. Uses the incremate helper
# to collect metrics from supporting files with some_* prefix.
#
# @see ../../lib/incremate.rb Implementation of the incremate helper
# @see https://github.com/yegor256/fbe/blob/master/lib/fbe/regularly.rb Implementation of Fbe.regularly
# @see https://github.com/yegor256/fbe/blob/master/lib/fbe/conclude.rb Implementation of Fbe.conclude
# @note Each supporting file with some_* prefix implements a specific metric calculation

require 'fbe/consider'
require 'fbe/fb'
require 'fbe/if_absent'
require 'fbe/pmp'
require_relative '../../lib/incremate'

days = Fbe.pmp.quality.qos_days
last = Fbe.fb.query(
  "(eq when
     (agg
       (eq what '#{$judge}')
       (max when)))"
).each.first
if last.nil?
  Fbe.fb.insert.then do |n|
    n.what = $judge
    n.when = Time.now.utc
    n.since = n.when - (days * 24 * 60 * 60)
  end
elsif last.when < Time.now.utc - (days * 24 * 60 * 60)
  Fbe.if_absent do |n|
    n.what = $judge
    n.since = last.when
    n.when = n.since + (days * 24 * 60 * 60)
  end
end
prev = nil
Fbe.consider("(and (eq what '#{$judge}') (exists since) (exists when))") do |f|
  if !prev.nil? && (f.since - prev.when).positive?
    Fbe.if_absent do |n|
      n.what = $judge
      n.since = prev.when
      n.when = f.since
    end
  end
  prev = f
end
Fbe.consider("(and (eq what '#{$judge}') (exists since) (exists when))") do |f|
  Jp.incremate(f, __dir__, 'some', avoid_duplicate: true)
end
Fbe.octo.print_trace!
