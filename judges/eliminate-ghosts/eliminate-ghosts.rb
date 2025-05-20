# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

# Judge that removes references to deleted GitHub users from the factbase.
# Checks all records with GitHub user references against the GitHub API,
# and if a user no longer exists (returns 404), removes the user reference
# from the factbase record to maintain data integrity.
#
# @see https://github.com/yegor256/fbe/blob/master/lib/fbe/conclude.rb Implementation of Fbe.conclude
# @see https://github.com/yegor256/fbe/blob/master/lib/fbe/delete.rb Implementation of Fbe.delete

require 'fbe/octo'
require 'fbe/conclude'
require 'fbe/delete'

Fbe.conclude do
  quota_aware
  on '(and (eq where "github") (exists who))'
  consider do |f|
    Fbe.octo.user(f.who)
  rescue Octokit::NotFound
    $loog.info("GitHub user ##{f.who} is not found")
    Fbe.delete(f, 'who')
  end
end
