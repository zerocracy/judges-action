# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative 'jp'

def Jp.labeled(events)
  events.each_with_index.filter_map do |te, i|
    next unless te[:event] == 'labeled'
    name = te.dig(:label, :name)
    te if events.drop(i + 1).none? { |e| e[:event] == 'unlabeled' && e.dig(:label, :name) == name }
  end
end
