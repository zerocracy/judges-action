# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require_relative 'jp'

def Jp.nick_of(who, loog: $loog)
  n = Fbe.octo.user_name_by_id(who)
  loog.debug("User ##{who} is actually @#{n}")
  n
end
