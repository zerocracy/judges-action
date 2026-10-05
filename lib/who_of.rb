# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/who'
require_relative 'jp'

def Jp.author(fact, id)
  if id.nil?
    fact.stale = 'who'
  else
    fact.who = id
  end
end

def Jp.mention(fact)
  return 'a user who has deleted the account' if fact['who'].nil?
  Fbe.who(fact)
end
