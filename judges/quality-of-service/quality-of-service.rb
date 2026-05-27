# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/consider'
require 'fbe/octo'
require 'fbe/pmp'
require_relative '../../lib/cover_qo'
require_relative '../../lib/incremate'
require_relative '../../lib/qos_search'

days = Fbe.pmp.quality.qos_days
pause = Fbe.pmp.quality.qos_pause_seconds.value || 0
Jp.qoreset
Jp.cover_qo(days)
Fbe.consider("(and (eq what '#{$judge}') (exists since) (exists when))") do |f|
  Jp.incremate(f, __dir__, 'some', avoid_duplicate: true, pause:)
end
Fbe.octo.print_trace!
