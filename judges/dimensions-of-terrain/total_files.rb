# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'

# Calculates the total number of files across all monitored GitHub repositories.
# This function retrieves file counts from repository trees, counting only blob
# items (files, not directories), and ignores empty repositories.
#
# This function is called from the "dimensions-of-terrain.rb" using the incremate
# helper to collect this specific metric as part of repository dimensions analysis.
#
# @param [Factbase::Fact] fact The fact object currently being processed
# @return [Hash] Map with total_files count as key-value pair
# @see ../dimensions-of-terrain.rb Main judge that calls this function
def total_files(_fact)
  files = 0
  Fbe.unmask_repos do |repo|
    repo_info = Fbe.octo.repository(repo)
    next if repo_info[:size].nil? || repo_info[:size].zero?
    Fbe.octo.tree(repo, repo_info[:default_branch], recursive: true).then do |json|
      files += json[:tree].count { |item| item[:type] == 'blob' }
    end
  end
  { total_files: files }
end
