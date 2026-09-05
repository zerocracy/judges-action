# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative 'jp'

def Jp.twice?(fb, fact, what, fields)
  pairs = fields.to_h { [_1, fact[_1]&.first] }
  fb.query(
    "(and (eq what $what) #{fields.map { pairs[_1].nil? ? "(absent #{_1})" : "(eq #{_1} $#{_1})" }.join(' ')})"
  ).each(fb, pairs.compact.merge('what' => what)).to_a.size > 1
end
