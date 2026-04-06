# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'json'
require_relative 'jp'

def Jp.supervision(context, loog: $loog)
  yield
rescue StandardError => e
  loog.error("Additional context for '#{e.class}: #{e.message}':\n#{JSON.pretty_generate(context)}")
  raise
end
