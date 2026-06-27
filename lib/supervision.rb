# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'json'
require_relative 'jp'

def Jp.supervision(context, loog: $loog)
  yield
rescue StandardError => e
  begin
    info = JSON.pretty_generate(context)
  rescue StandardError => je
    info = "Failed to serialize context: #{je.message}\n#{context.inspect}"
  end
  loog.error("Additional context for '#{e.class}: #{e.message}':\n#{info}")
  raise
end
