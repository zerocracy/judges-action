# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative 'jp'

def Jp.fill_fact_by_hash(fact, hash)
  hash.each do |prop, value|
    raise(ArgumentError, "Invalid property name: #{prop.inspect}") unless /^[a-z][a-z_0-9]*$/i.match?(prop.to_s)
    fact.__send__(:"#{prop}=", value)
  end
end
