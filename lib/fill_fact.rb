# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative 'jp'

# This method fill fact by given hash
#
# @param [Factbase::Fact] fact The fact object to accumulate data into.
# @param [Hash] hash The data that will be added to the fact
# @return [nil] This method modifies the fact in-place and returns nil
def Jp.fill_fact_by_hash(fact, hash)
  hash.each do |prop, value|
    fact.send(:"#{prop}=", value)
  end
end
