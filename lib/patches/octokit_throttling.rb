# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'octokit'

class Octokit::Error
  class << self
    alias original_from_response from_response

    def from_response(response) # rubocop:disable Elegant/GoodMethodName
      return Octokit::TooManyRequests.new(response) if response[:status].to_s == '429'
      original_from_response(response)
    end
  end
end
