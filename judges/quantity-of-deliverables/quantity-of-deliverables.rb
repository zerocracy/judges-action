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
require 'fbe/octo'
require 'fbe/pmp'
require_relative '../../lib/incremate'
require_relative '../../lib/cover_qo'

days = Fbe.pmp.scope.qod_days
Jp.cover_qo(days)
Fbe.consider("(and (eq what '#{$judge}') (exists since) (exists when))") do |f|
  Jp.incremate(f, __dir__, 'total', avoid_duplicate: true)
end
Fbe.octo.print_trace!
