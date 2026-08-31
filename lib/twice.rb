# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative 'jp'

def Jp.twice?(fb, fact, what, fields)
  pairs = fields.to_h { [_1, fact[_1]&.first] }
  pairs.compact!
  fb.query(
    "(and (eq what $what) #{pairs.keys.map { "(eq #{_1} $#{_1})" }.join(' ')})"
  ).each(fb, pairs.merge('what' => what)).to_a.size > 1
end
