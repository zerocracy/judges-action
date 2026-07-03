# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/fb'
require 'fbe/octo'
require 'time'
require_relative '../../lib/incremate'

begin
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
rescue StandardError => e
  $loog.warn("[#{$judge}] Dimensions-of-terrain judge failed: #{e.class}: #{e.message}")
end

Fbe.octo.print_trace!
