# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/who'
require_relative 'jp'

# Writes the author id into the fact, marking the property stale when GitHub
# gave no author, which happens when the account has been deleted.
def Jp.set_who(fact, id)
  if id.nil?
    fact.stale = 'who'
  else
    fact.who = id
  end
end

# How to name the author of the fact in a human-readable line.
def Jp.mention_of(fact)
  return 'a user who has deleted the account' if fact['who'].nil?
  Fbe.who(fact)
end
