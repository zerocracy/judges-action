# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/fb'
require 'fbe/octo'
require 'time'
require_relative '../../lib/incremate'

today =
  begin
    v = ENV.fetch('TODAY', nil)
    if v.nil? || v.empty?
      Time.now.utc
    else
      Time.parse(v)
    end
  end
f = Fbe.fb.query(
  "(and
    (eq what '#{$judge}')
    (gt when (minus (to_time '#{today.utc.iso8601}') '1 days')))"
).each.first
if f.nil?
  f = Fbe.fb.insert
  f.what = $judge
  f.when = today
end

Jp.incremate(f, __dir__, 'total')

Fbe.octo.print_trace!
