# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require_relative 'jp'

def Jp.nick_of(who, loog: $loog)
  n = Fbe.octo.user_name_by_id(who)
  loog.debug("User ##{who} is actually @#{n}")
  n
rescue Octokit::NotFound, Octokit::Deprecated => e
  loog.info("The user ##{who} is absent in GitHub: #{e.message}")
  nil
rescue Octokit::Forbidden => e
  loog.warn(
    "[Jp.nick_of] The user ##{who} is not accessible in GitHub " \
    "(transient, will retry next cycle): #{e.class}: #{e.message}"
  )
  raise
rescue Octokit::TooManyRequests, Octokit::Unauthorized, Octokit::ServerError,
  Octokit::Conflict, Octokit::UnprocessableEntity,
  Net::OpenTimeout, Net::ReadTimeout, SocketError,
  Errno::ECONNRESET, Errno::ETIMEDOUT => e
  loog.warn("[Jp.nick_of] Transient error fetching user ##{who} in GitHub (fail fast): #{e.class}: #{e.message}")
  raise
end
