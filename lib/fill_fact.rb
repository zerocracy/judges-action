# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative 'jp'

def Jp.fill_fact_by_hash(fact, hash)
  hash.each do |prop, value|
    fact.send(:"#{prop}=", value)
  end
end
