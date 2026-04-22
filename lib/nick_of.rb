# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'octokit'
require_relative 'jp'

def Jp.nick_of(who, loog: $loog)
  n = Fbe.octo.user_name_by_id(who)
  loog.debug("User ##{who} is actually @#{n}")
  n
rescue Octokit::NotFound, Octokit::Deprecated => e
  loog.warn("The user ##{who} is absent in GitHub: #{e.message}")
  nil
rescue Octokit::Forbidden => e
  loog.warn("[Jp.nick_of] The user ##{who} is not accessible in GitHub: #{e.class}: #{e.message}")
  nil
end
