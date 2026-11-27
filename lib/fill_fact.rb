# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative 'jp'

def Jp.fill_fact_by_hash(fact, hash)
  raise(ArgumentError, 'The fact cannot be nil') if fact.nil?
  raise(ArgumentError, 'The hash cannot be nil') if hash.nil?
  hash.each do |prop, value|
    raise(ArgumentError, "Invalid property name: #{prop.inspect}") unless /\A[_a-z][a-zA-Z0-9_]*\z/.match?(prop.to_s)
    raise(ArgumentError, "The value of #{prop.inspect} can't be nil") if value.nil?
    values = value.is_a?(Array) ? value : [value]
    raise(ArgumentError, "The value of #{prop.inspect} can't be empty") if values.empty?
    raise(ArgumentError, "The value of #{prop.inspect} can't hold a nil") if values.any?(&:nil?)
    values.each { |v| fact.public_send(:"#{prop}=", v) }
  end
end
