# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

# Judge that collects metrics about GitHub repositories dimensions.
# It aggregates various statistics like total files, contributors, stars,
# repositories, commits, issues, releases, and active contributors.
# Runs daily and uses the incremate helper to collect metrics from supporting files.
#
# @see ../../lib/incremate.rb Implementation of the incremate helper
# @note Each supporting file with total_* prefix implements a specific metric collection

require 'time'
require 'fbe/fb'
require 'fbe/octo'
require_relative '../../lib/incremate'

f = Fbe.fb.query(
  "(and
    (eq what '#{$judge}')
    (gt when (minus (to_time (env 'TODAY' '#{Time.now.utc.iso8601}')) '1 days')))"
).each.first
if f.nil?
  f = Fbe.fb.insert
  f.what = $judge
  f.when = Time.now
end

Jp.incremate(f, __dir__, 'total')

Fbe.octo.print_trace!
