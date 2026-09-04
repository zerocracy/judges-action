# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative 'jp'

def Jp.postpone(repo, error)
  $loog.warn("[#{$judge}] Cannot measure #{repo}, postponing the metric: #{error.class}: #{error.message}")
  throw(:postponed, {})
end

def Jp.measured(&)
  catch(:postponed, &)
end
