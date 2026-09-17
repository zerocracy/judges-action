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
    raise(ArgumentError, "The value of #{prop.inspect} can't be nil") if value.nil?
    values = Array(value)
    raise(ArgumentError, "The value of #{prop.inspect} can't be empty") if values.empty?
    raise(ArgumentError, "The value of #{prop.inspect} can't hold a nil") if values.any?(&:nil?)
    values.each { |v| fact.public_send(:"#{prop}=", v) }
  end
end
