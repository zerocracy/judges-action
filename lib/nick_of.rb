# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'octokit'
require_relative 'jp'

# Get nick of GitHub user or NIL if this user is dead.
#
# @param [Integer] who The ID of GitHub user
# @return [String, nil] Either name or NIL if dead
def Jp.nick_of(who, loog: $loog)
  n = Fbe.octo.user_name_by_id(who)
  loog.debug("User ##{who} is actually @#{n}")
  n
rescue Octokit::NotFound => e
  loog.warn("The user ##{who} is absent in GitHub: #{e.message}")
  nil
end
