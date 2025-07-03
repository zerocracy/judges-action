# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

# Judge that monitors open issue and create missing issue-was-assigned facts.

require 'fbe/conclude'
require 'fbe/octo'

Fbe.conclude do
  quota_aware
  on "(and
    (eq where 'github')
    (eq what 'issue-was-opened')
    (exists issue)
    (exists repository)
    (empty
      (and
        (eq where $where)
        (eq repository $repository)
        (eq issue $issue)
        (eq what '#{$judge}'))))"
  consider do |f|
    repo = Fbe.octo.repo_name_by_id(f.repository)
    Fbe.octo.issue_events(repo, f.issue).find { _1[:event] == 'assigned' }.then do |event|
      next if event.nil?
      Fbe.fb.txn do |fbt|
        fbt.insert.then do |n|
          n.where = f.where
          n.what = $judge
          n.repository = f.repository
          n.issue = f.issue
          n.who = event.dig(:assignee, :id)
          n.assigner = event.dig(:assigner, :id)
          n.when = event[:created_at]
          n.details = "#{Fbe.issue(n)} was assigned to #{Fbe.who(n)} by #{Fbe.who(n, :assigner)} ."
        end
      end
    end
  end
end

Fbe.octo.print_trace!
