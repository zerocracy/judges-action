# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

# Judge that monitors open issue and create missing issue-was-assigned facts

require 'fbe/conclude'
require 'fbe/octo'

Fbe.conclude do
  quota_aware
  on "(and
        (eq where 'github')
        (eq what 'issue-was-opened')
        (empty
          (and
            (eq where 'github')
            (eq repository $repository)
            (eq issue $issue)
            (eq what 'issue-was-assigned'))))"

  consider do |f|
    Fbe.octo.issue_events(
      Fbe.octo.repo_name_by_id(f.repository),
      f.issue
    ).find { _1[:event] == 'assigned' }.then do |event|
      next if event.nil?
      Fbe.fb.txn do |fbt|
        fbt.insert.then do |fact|
          fact.where = f.where
          fact.what = 'issue-was-assigned'
          fact.repository = f.repository
          fact.issue = f.issue
          fact.who = event.dig(:assignee, :id)
          fact.assigner = event.dig(:assigner, :id)
          fact.when = event[:created_at]
        end
      end
    end
  end
end
