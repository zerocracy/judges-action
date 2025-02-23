# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'

# Total number of files for all repos
#
# This function is called from the "dimensions-of-terrain.rb".
#
# @param [Factbase::Fact] fact The fact just under processing
# @return [Hash] Map with keys as fact attributes and values as integers
def total_files(_fact)
  files = 0
  Fbe.unmask_repos.each do |repo|
    repo_info = Fbe.octo.repository(repo)
    next if repo_info[:size].zero?
    Fbe.octo.tree(repo, repo_info[:default_branch], recursive: true).then do |json|
      files += json[:tree].count { |item| item[:type] == 'blob' }
    end
  end
  { total_files: files }
end
