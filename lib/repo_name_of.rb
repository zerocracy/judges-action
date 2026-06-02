# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'octokit'
require_relative 'jp'

def Jp.repo_name_of(repository, loog: $loog)
  [Fbe.octo.repo_name_by_id(repository), :ok]
rescue Octokit::NotFound, Octokit::Deprecated => e
  loog.info("Repository ##{repository} doesn't exist in GitHub: #{e.message}")
  [nil, :lost]
rescue Octokit::Forbidden => e
  loog.warn(
    "[#{$judge}] Access forbidden to repository ##{repository} " \
    "(transient, will retry next cycle): #{e.class}: #{e.message}"
  )
  [nil, :transient]
end
