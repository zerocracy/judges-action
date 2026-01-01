# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'octokit'
require_relative 'jp'

# Retrieves the GitHub username (nickname) for a given user ID.
#
# This method attempts to fetch the username associated with a GitHub user ID
# through the GitHub API. It handles cases where the user no longer exists
# (deleted accounts, suspended users, etc.) by returning nil instead of
# raising an exception.
#
# The method is useful for safely retrieving user information when processing
# historical GitHub data where users may have been removed from the platform.
#
# @example
#   # Get username for an existing user
#   nick = Jp.nick_of(12345)
#   # => "octocat"
#
#   # Handle a deleted user
#   nick = Jp.nick_of(99999999)
#   # => nil
#
# @param [Integer] who The numeric GitHub user ID to look up
# @param [Logger] loog The logger instance for debug and warning messages
#   (defaults to the global $loog)
# @return [String, nil] The GitHub username if the user exists, or nil if the
#   user was not found (deleted, suspended, or invalid ID)
def Jp.nick_of(who, loog: $loog)
  n = Fbe.octo.user_name_by_id(who)
  loog.debug("User ##{who} is actually @#{n}")
  n
rescue Octokit::NotFound, Octokit::Deprecated => e
  loog.warn("The user ##{who} is absent in GitHub: #{e.message}")
  nil
end
