# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'octokit'

# GitHub answers a throttled request with either 403 or 429. Octokit builds
# TooManyRequests for the 403 only: its "from_response" has no case for 429, so
# a 429 falls through to ClientError, which is also the parent of NotFound,
# Forbidden and Unauthorized and therefore cannot be rescued as "throttled"
# without swallowing them too. Here a 429 becomes TooManyRequests, so the
# clauses that already rescue throttling catch both halves of it.
module Octokit
  class Error
    class << self
      alias from_response_without_429 from_response

      # Build an error out of an HTTP response.
      # @param [Hash] response The response from GitHub
      # @return [Octokit::Error] The error
      def from_response(response)
        return Octokit::TooManyRequests.new(response) if response[:status].to_i == 429
        from_response_without_429(response)
      end
    end
  end
end
