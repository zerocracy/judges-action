# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

# Judge that monitors open issue and create missing issue-was-assigned facts.

require 'fbe/iterate'
require 'fbe/octo'
require_relative '../../lib/issue_was_lost'

Fbe.iterate do
  as 'assignees-were-scanned'
  by "(agg
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
          (eq where $where)))
      (eq where 'github'))
    (min issue))"
  repeats 64
  over(timeout: ($options.timeout || 60) * 0.8) do |repository, issue|
    repo = Fbe.octo.repo_name_by_id(repository)
    events =
      begin
        Fbe.octo.issue_events(repo, issue).select { |e| e[:event] == 'assigned' }
      rescue Octokit::NotFound => e
        $loog.info("Not found issue events for issue ##{issue} in #{repo}: #{e.message}")
        Jp.issue_was_lost('github', repository, issue)
        next issue
      end
    events.each do |event|
      nn =
        Fbe.if_absent do |n|
          n.where = 'github'
          n.repository = repository
          n.issue = issue
          n.what = $judge
          n.who = event.dig(:assignee, :id)
          n.assigner = event.dig(:assigner, :id)
          n.when = event[:created_at]
        end
      raise "Assignee already exists in #{repo}##{issue}" if nn.nil?
      nn.details = "#{Fbe.issue(nn)} was assigned to #{Fbe.who(nn)} by #{Fbe.who(nn, :assigner)}."
      $loog.info("Assignee found for #{Fbe.issue(nn)} (fact ##{nn._id}): #{Fbe.who(nn)}")
    end
    issue
  end
end

Fbe.octo.print_trace!
