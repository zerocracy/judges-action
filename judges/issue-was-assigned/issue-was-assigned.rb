# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/issue'
require 'fbe/iterate'
require 'fbe/octo'
require 'fbe/who'
require 'tago'
require_relative '../../lib/issue_was_lost'

repos = {}
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
    repo =
      repos[repository] ||=
        begin
          Fbe.octo.repo_name_by_id(repository)
        rescue Octokit::NotFound, Octokit::Deprecated => e
          $loog.info("Repository ##{repository} not found: #{e.message}")
          next issue
        rescue Octokit::Forbidden => e
          $loog.warn(
            "[#{$judge}] Access forbidden to repository ##{repository} " \
            "(transient, will retry next cycle): #{e.class}: #{e.message}"
          )
          next issue
        end
    events =
      begin
        Fbe.octo.issue_events(repo, issue).select { |e| e[:event] == 'assigned' }
      rescue Octokit::NotFound, Octokit::Deprecated => e
        $loog.info("Not found issue events for issue ##{issue} in #{repo}: #{e.message}")
        Jp.issue_was_lost('github', repository, issue)
        next issue
      rescue Octokit::Forbidden => e
        $loog.warn(
          "[#{$judge}] Access forbidden to issue events for issue ##{issue} in #{repo} " \
          "(transient, will retry next cycle): #{e.class}: #{e.message}"
        )
        next issue
      end
    events.each do |event|
      who = event.dig(:assignee, :id)
      if who.nil?
        $loog.info("The assignee of #{repo}##{issue} is absent, skipping the event")
        next
      end
      Fbe.fb.txn do |fbt|
        nn =
          Fbe.if_absent(fb: fbt) do |n|
            n.issue = issue
            n.who = who
            n.what = $judge
            n.repository = repository
            n.where = 'github'
          end
        if nn.nil?
          $loog.warn("Assignee already exists in #{repo}##{issue}")
          next
        end
        assigner = event.dig(:assigner, :id)
        if assigner
          nn.assigner = assigner
        else
          nn.stale = 'assigner'
        end
        nn.when = event[:created_at]
        nn.details =
          if assigner
            "#{Fbe.issue(nn)} was assigned to #{Fbe.who(nn)} by #{Fbe.who(nn, :assigner)}."
          else
            "#{Fbe.issue(nn)} was assigned to #{Fbe.who(nn)}."
          end
        $loog.info("The issue #{Fbe.issue(nn)} was assigned to #{Fbe.who(nn)} #{nn.when.ago} ago (fact ##{nn._id})")
      end
    end
    issue
  end
end

Fbe.octo.print_trace!
