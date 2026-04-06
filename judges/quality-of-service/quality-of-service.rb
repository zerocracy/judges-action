# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

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
