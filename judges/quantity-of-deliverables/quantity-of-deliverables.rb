# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

# Judge that tracks the quantity of deliverables in GitHub repositories.
# Regularly collects metrics about activities like commits pushed,
# releases published, issues created, builds ran, and reviews submitted.
# Uses the Fbe.regularly helper to run at defined intervals and the
# incremate function to collect metrics from supporting files.
#
# @see ../../lib/incremate.rb Implementation of the incremate helper
# @see https://github.com/yegor256/fbe/blob/master/lib/fbe/regularly.rb Implementation of Fbe.regularly
# @note Each supporting file with total_* prefix implements a specific metric collection

require 'fbe/consider'
require 'fbe/regularly'
require_relative '../../lib/incremate'

Fbe.regularly('scope', 'qod_interval', 'qod_days') do |f|
  Jp.incremate(f, __dir__, 'total')
end

Fbe.consider(
  "(and
    (eq what '#{$judge}')
    (absent since)
    (exists when))"
) do |f|
  pmp = Fbe.fb.query("(and (eq what 'pmp') (eq area 'scope') (exists qod_days))").each.to_a.first
  f.since = f.when - (((!pmp.nil? && pmp['qod_days']&.first) || 28) * 24 * 60 * 60)
end

Fbe.consider("(and (eq what '#{$judge}') (exists since))") do |f|
  Jp.incremate(f, __dir__, 'total', avoid_duplicate: true)
end

Fbe.octo.print_trace!
