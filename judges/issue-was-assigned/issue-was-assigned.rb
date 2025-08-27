# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

# Judge that monitors open issue and create missing issue-was-assigned facts.

require 'fbe/iterate'
require 'fbe/octo'

Fbe.iterate do
  as 'assignees-were-scanned'
  by "(agg
    (and
      (gt issue $before)
      (eq what 'issue-was-opened')
      (eq repository $repository)
      (absent stale)
      (empty
        (and
          (eq issue $issue)
          (eq repository $repository)
          (eq what '#{$judge}')
          (eq where $where)))
      (eq where 'github'))
    (min issue))"
  quota_aware
  repeats 100
  over(timeout: ($options.timeout || 60) * 0.8) do |repository, issue|
    begin
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
        if nn.nil?
          $loog.info("Assignee already exists in #{repo}##{issue}")
          next issue
        end
        nn.details = "#{Fbe.issue(nn)} was assigned to #{Fbe.who(nn)} by #{Fbe.who(nn, :assigner)} ."
        $loog.info("Assignee found for #{Fbe.issue(nn)}: #{Fbe.who(nn)}")
      end
    rescue Octokit::NotFound => e
      $loog.info("Not found issue events for issue ##{issue} in #{repo}: #{e.message}")
    end
    issue
  end
end

Fbe.octo.print_trace!
