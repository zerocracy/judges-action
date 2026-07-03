# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/consider'
require 'fbe/octo'
require 'fbe/pmp'
require_relative '../../lib/cover_qo'
require_relative '../../lib/incremate'

days = Fbe.pmp.scope.qod_days
begin
  Jp.cover_qo(days)
  Fbe.consider("(and (eq what '#{$judge}') (exists since) (exists when))") do |f|
    Jp.incremate(f, __dir__, 'total', avoid_duplicate: true)
  end
rescue StandardError => e
  $loog.warn("[#{$judge}] Quantity-of-deliverables judge failed: #{e.class}: #{e.message}")
end
Fbe.octo.print_trace!
