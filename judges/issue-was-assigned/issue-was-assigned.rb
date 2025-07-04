# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

# Judge that monitors open issue and create missing issue-was-assigned facts.

require 'fbe/conclude'
require 'fbe/octo'

Fbe.iterate do
  as 'assignees-were-scanned'
  by "(agg
    (and
      (eq where 'github')
      (eq what 'issue-was-opened')
      (eq repository $repository)
      (gt issue $before)
      (empty
        (and
          (eq where $where)
          (eq repository $repository)
          (eq issue $issue)
          (eq what '#{$judge}'))))
    (min issue))"
  quota_aware
  repeats 100
  over(timeout: 5 * 60) do |repository, issue|
    repo = Fbe.octo.repo_name_by_id(repository)
    Fbe.octo.issue_events(repo, issue).find { _1[:event] == 'assigned' }.then do |event|
      next if event.nil?
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
      next if nn.nil?
      nn.details = "#{Fbe.issue(nn)} was assigned to #{Fbe.who(nn)} by #{Fbe.who(nn, :assigner)} ."
    end
    issue
  end
end

Fbe.octo.print_trace!
