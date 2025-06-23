# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

# Judge that monitors facts with exists repository and issue properties and
# create missing issue-was-opened fact.

require 'fbe/octo'
require 'fbe/conclude'
require 'fbe/issue'
require 'fbe/who'

Fbe.conclude do
  quota_aware
  on "(and
    (eq what 'issue-was-closed')
    (eq where 'github')
    (exists repository)
    (exists what)
    (exists issue)
    (not (exists stale))
    (unique issue)
    (empty
      (and
        (eq where 'github')
        (eq repository $repository)
        (eq issue $issue)
        (eq what 'pull-was-opened'))))"
  follow 'where repository issue'
  draw do |n, f|
    repo = Fbe.octo.repo_name_by_id(f.repository)
    begin
      json = Fbe.octo.issue(repo, f.issue)
      n.when = json[:created_at]
      n.who = json.dig(:user, :id)
      n.details = "#{Fbe.issue(n)} has been opened by #{Fbe.who(n)}."
    rescue Octokit::NotFound
      $loog.info("The issue ##{f.issue} doesn't exist in #{repo}")
      next
    end
  end
end

Fbe.octo.print_trace!
