# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'

def total_files(_fact)
  guard = $terrainguard
  files = 0
  guard.eachrepo do |repo|
    info = guard.repository(repo)
    next if info.nil?
    next if info[:size].nil? || info[:size].zero?
    json = guard.tree(repo, info[:default_branch])
    next if json.nil?
    files += json[:tree].count { |item| item[:type] == 'blob' }
  end
  { total_files: files }
end
