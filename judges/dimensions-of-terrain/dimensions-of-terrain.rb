# frozen_string_literal: true

# MIT License
#
# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'time'
require 'fbe/fb'
require_relative '../../lib/incremate'

f = Fbe.fb.query(
  "(and
    (eq what '#{$judge}')
    (gt when (minus (to_time (env 'TODAY' '#{Time.now.utc.iso8601}')) '1 days')))"
).each.to_a.first
if f.nil?
  f = Fbe.fb.insert
  f.what = $judge
  f.when = Time.now
end

Jp.incremate(f, __dir__, 'total')
