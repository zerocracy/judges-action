# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

# Judge that monitors issue-was-assigned facts and add unassigned property if needed.

require 'fbe/consider'
require 'fbe/issue'
require 'fbe/octo'
require 'fbe/who'
require 'tago'
require_relative '../../lib/issue_was_lost'
require_relative '../../lib/supervision'

Fbe.consider(
  "(and
     (eq what 'issue-was-assigned')
     (absent unassigned)
     (absent stale)
     (absent tombstone)
     (absent done)
     (eq where 'github'))"
) do |f|
  Jp.supervision({ 'repository' => f.repository, 'issue' => f.issue }) do
    repo = Fbe.octo.repo_name_by_id(f.repository)
    event =
      begin
        Fbe.octo.issue_events(repo, f.issue).sort_by { _1[:created_at] }.find do |e|
          e[:event] == 'unassigned' && e.dig(:assignee, :id) == f.who && e[:created_at] > f.when
        end
      rescue Octokit::NotFound, Octokit::Deprecated => e
        $loog.info("Not found issue events for issue ##{f.issue} in #{repo}: #{e.message}")
        Jp.issue_was_lost('github', f.repository, f.issue)
        next
      end
    next if event.nil?
    f.unassigned = event[:created_at]
    $loog.info("Github user #{Fbe.who(f)} was unassigned in #{Fbe.issue(f)} #{f.unassigned.ago} ago")
  end
end

Fbe.octo.print_trace!
