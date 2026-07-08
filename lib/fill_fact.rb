# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative 'jp'

Jp::FILL_FACT_FORBIDDEN = %w[all_properties method_missing].freeze

def Jp.fill_fact_by_hash(fact, hash)
  hash.each do |prop, value|
    raise(ArgumentError, "Invalid property name: #{prop.inspect}") unless /\A[a-z][a-z_0-9]*\z/i.match?(prop.to_s)
    if Jp::FILL_FACT_FORBIDDEN.include?(prop.to_s)
      raise(ArgumentError, "Forbidden property name: #{prop.inspect} (conflicts with fact API)")
    end
    fact.public_send(:"#{prop}=", value)
  end
end
