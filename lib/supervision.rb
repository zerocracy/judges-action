# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'json'
require_relative 'jp'

# A decorator to wrap a method call by adding additional context that will be logged if an exception occurs.
#
# @param [Hash] context The data that will be written to the log if an exception occurs
# @param [Logger] loog The logger instance for error messages
# @yield Block with calling method
# @raise [StandardError] If calling method raise error, it will be propagate further
# @example
#   $loog = Loog::VERBOSE
#   repo = 'zerocracy/judges-action'
#   issue = 125
#   Jp.supervision({ 'repo' => repo, 'issue' => issue }) do
#     Fbe.octo.issue(repo, issue) # if raise error, repo and issue will be logged
#   end
def Jp.supervision(context, loog: $loog)
  yield
rescue StandardError => e
  loog.error("Additional context for '#{e.class}: #{e.message}':\n#{JSON.pretty_generate(context)}")
  raise
end
