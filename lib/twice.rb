# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative 'jp'

def Jp.twice?(fb, fact, what, fields)
  pairs = fields.map { [_1, fact[_1]&.first] }
  pairs.reject! { _1.last.nil? }
  fb.query(
    "(and (eq what '#{what}') " \
    "#{pairs.map do |prop, value|
      case value
      when String then "(eq #{prop} '#{value.gsub("'", "\\\\'")}')"
      when Time then "(eq #{prop} #{value.utc.iso8601})"
      else "(eq #{prop} #{value})"
      end
    end.join(' ')})"
  ).each.to_a.size > 1
end
