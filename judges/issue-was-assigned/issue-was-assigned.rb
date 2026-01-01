# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

# Judge that monitors open issue and create missing issue-was-assigned facts.

require 'fbe/issue'
require 'fbe/iterate'
require 'fbe/octo'
require 'fbe/who'
require 'tago'
require_relative '../../lib/issue_was_lost'

Fbe.iterate do
  as 'assignees_were_scanned'
  sort_by 'issue'
  by "
    (and
      (gt issue $before)
      (eq what 'issue-was-opened')
      (eq repository $repository)
      (absent stale)
      (absent tombstone)
      (absent done)
      (empty
        (and
          (eq issue $issue)
          (eq repository $repository)
          (eq what '#{$judge}')
          (eq where $where)
          (absent unassigned)))
      (eq where 'github'))"
  repeats 64
  over do |repository, issue|
    repo = Fbe.octo.repo_name_by_id(repository)
    events =
      begin
        Fbe.octo.issue_events(repo, issue).select { |e| e[:event] == 'assigned' }
      rescue Octokit::NotFound, Octokit::Deprecated => e
        $loog.info("Not found issue events for issue ##{issue} in #{repo}: #{e.message}")
        Jp.issue_was_lost('github', repository, issue)
        next issue
      end
    events.each do |event|
      Fbe.fb.txn do |fbt|
        nn =
          Fbe.if_absent(fb: fbt) do |n|
            n.issue = issue
            n.who = event.dig(:assignee, :id)
            n.what = $judge
            n.repository = repository
            n.where = 'github'
          end
        if nn.nil?
          $loog.warn("Assignee already exists in #{repo}##{issue}")
          next
        end
        nn.assigner = event.dig(:assigner, :id)
        nn.when = event[:created_at]
        nn.details = "#{Fbe.issue(nn)} was assigned to #{Fbe.who(nn)} by #{Fbe.who(nn, :assigner)}."
        $loog.info("The issue #{Fbe.issue(nn)} was assigned to #{Fbe.who(nn)} #{nn.when.ago} ago (fact ##{nn._id})")
      end
    end
    issue
  end
end

Fbe.octo.print_trace!
