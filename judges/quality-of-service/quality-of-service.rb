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
require 'fbe/octo'
require 'fbe/pmp'
require_relative '../../lib/incremate'
require_relative '../../lib/cover_qo'

days = Fbe.pmp.quality.qos_days
Jp.cover_qo(days)
Fbe.consider("(and (eq what '#{$judge}') (exists since) (exists when))") do |f|
  Jp.incremate(f, __dir__, 'some', avoid_duplicate: true)
end
Fbe.octo.print_trace!
