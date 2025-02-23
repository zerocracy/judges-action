# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/conclude'

Fbe.conclude do
  quota_aware
  on '(and (eq where "github") (exists who) (not (exists is_human)))'
  consider do |f|
    json = Fbe.octo.user(f.who)
    type = json[:type]
    if type == 'Bot' || json[:login] == 'rultor' || json[:login] == '0pdd'
      f.is_human = 0
      $loog.info("GitHub user ##{f.who} (@#{json[:login]}) is actually a bot")
    else
      f.is_human = 1
      $loog.info("GitHub user ##{f.who} (@#{json[:login]}) is not a bot")
    end
  end
end
