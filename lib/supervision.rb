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
    info =
      begin
        "Failed to serialize context: #{je.message}\n#{context.inspect}"
      rescue StandardError
        "Failed to serialize context: #{je.message}"
      end
  end
  loog.error(
    "Additional context for '#{e.class}: #{begin
      e.message.encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
    rescue EncodingError
      e.message.inspect
    end}':\n#{info}"
  )
  raise
end
