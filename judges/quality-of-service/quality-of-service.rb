# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/consider'
require 'fbe/octo'
require 'fbe/pmp'
require_relative '../../lib/cover_qo'
require_relative '../../lib/incremate'
require_relative '../../lib/qos_param'
require_relative '../../lib/qos_search'

days = Fbe.pmp.quality.qos_days
pause = Jp.qos_param(:qos_pause_seconds, 0)
limit = Jp.qos_param(:qos_max_per_fact)
Jp.qoreset
Jp.cover_qo(days)
Fbe.consider("(and (eq what '#{$judge}') (exists since) (exists when))") do |f|
  Jp.incremate(f, __dir__, 'some', avoid_duplicate: true, pause:, max_per_fact: limit)
end
Fbe.octo.print_trace!
