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
        (eq issue $issue)
        (eq repository $repository)
        (eq where 'github')
        (eq what '#{$judge}'))))"
  follow 'where repository issue'
  draw do |n, f|
    repo = Fbe.octo.repo_name_by_id(f.repository)
    begin
      json = Fbe.octo.issue(repo, f.issue)
      n.what = $judge
      n.when = json[:created_at]
      n.who = json.dig(:user, :id)
      n.details = "#{Fbe.issue(n)} has been opened by #{Fbe.who(n)}."
      $loog.info("The opening of #{Fbe.issue(n)} by #{Fbe.who(n)} was found")
    rescue Octokit::NotFound
      $loog.info("The issue ##{f.issue} doesn't exist in #{repo}")
      f.stale = "issue #{f.issue}"
      throw :rollback
    end
  end
end

Fbe.octo.print_trace!
