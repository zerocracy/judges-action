# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

# Judge that monitors facts with exists repository and issue properties and
# create missing issue-was-opened fact.

require 'fbe/octo'
require 'fbe/conclude'
require 'fbe/issue'
require 'fbe/tombstone'
require 'fbe/who'
require 'octokit'
require 'tago'
require_relative '../../lib/issue_was_lost'

Fbe.conclude do
  on "(and
    (or
      (eq what 'dud-was-closed')
      (eq what 'issue-was-closed')
      (eq what 'bug-was-accepted')
      (eq what 'bug-was-resolved')
      (eq what 'enhancement-suggestion-was-rewarded')
      (eq what 'bug-report-was-rewarded')
      (eq what 'enhancement-was-accepted'))
    (exists repository)
    (exists issue)
    (absent stale)
    (absent tombstone)
    (absent done)
    (eq where 'github')
    (unique where repository issue)
    (empty
      (and
        (eq issue $issue)
        (eq repository $repository)
        (eq where $where)
        (eq what '#{$judge}'))))"
  follow 'where repository issue'
  draw do |n, f|
    repo = Fbe.octo.repo_name_by_id(f.repository)
    json =
      begin
        Fbe.octo.issue(repo, f.issue)
      rescue Octokit::NotFound, Octokit::Deprecated => e
        $loog.info("The issue ##{f.issue} doesn't exist in #{repo}: #{e.message}")
        Jp.issue_was_lost(f.where, f.repository, f.issue)
        next
      end
    n.what = $judge
    n.when = json[:created_at]
    n.who = json.dig(:user, :id)
    n.details = "The issue #{Fbe.issue(n)} has been opened earlier by #{Fbe.who(n)}."
    $loog.info("The issue #{Fbe.issue(n)} was opened by #{Fbe.who(n)} #{n.when.ago} ago")
  end
end

Fbe.octo.print_trace!
