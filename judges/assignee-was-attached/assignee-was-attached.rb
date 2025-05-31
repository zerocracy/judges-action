# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

# Judge that monitors open issue and create missing issue-was-assigned facts

require 'fbe/conclude'
require 'fbe/octo'

Fbe.conclude do
  quota_aware
  on "(and (eq where 'github') (eq what 'issue-was-opened'))"

  consider do |f|
    next if Fbe.fb.query(
      "(and
         (eq where 'github')
         (eq repository #{f.repository})
         (eq issue #{f.issue})
         (eq what 'issue-was-closed'))"
    ).each.to_a.first
    Fbe.octo.issue_events(
      Fbe.octo.repo_name_by_id(f.repository),
      f.issue
    ).select { _1[:event] == 'assigned' }.each do |event|
      fact =
        Fbe.if_absent do |fact|
          fact.where = f.where
          fact.what = 'issue-was-assigned'
          fact.repository = f.repository
          fact.issue = f.issue
          fact.issue_event_id = event[:id]
        end
      next if fact.nil?
      fact.who = event.dig(:assignee, :id)
      fact.assigner = event.dig(:assigner, :id)
      fact.when = event[:created_at]
    end
  end
end
