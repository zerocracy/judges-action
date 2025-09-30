# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

# Judge that monitors issues which were closed.

require 'fbe/if_absent'
require 'fbe/issue'
require 'fbe/iterate'
require 'fbe/octo'
require 'fbe/who'
require_relative '../../lib/issue_was_lost'

Fbe.iterate do
  as 'issues_were_scanned'
  by "(agg
    (and
      (gt issue $before)
      (or
        (eq what 'issue-was-opened')
        (eq what 'bug-was-accepted')
        (eq what 'bug-was-resolved')
        (eq what 'enhancement-was-accepted')
        (eq what 'resolved-bug-was-rewarded')
        (eq what 'bug-report-was-rewarded')
        (eq what 'enhancement-suggestion-was-rewarded'))
      (eq repository $repository)
      (absent stale)
      (absent tombstone)
      (absent done)
      (empty
        (and
          (eq issue $issue)
          (eq repository $repository)
          (eq what 'issue-was-closed')
          (eq where $where)))
      (eq where 'github'))
    (min issue))"
  repeats 64
  over do |repository, issue|
    repo = Fbe.octo.repo_name_by_id(repository)
    json =
      begin
        Fbe.octo.issue(repo, issue)
      rescue Octokit::NotFound, Octokit::Deprecated => e
        $loog.info("The issue #{repo}##{issue} doesn't exist: #{e.message}")
        Jp.issue_was_lost('github', repository, issue)
        next issue
      end
    unless json[:state] == 'closed'
      $loog.debug("Issue #{repo}##{issue} is not closed: #{json[:state].inspect}")
      next issue
    end
    Fbe.fb.txn do |fbt|
      nn =
        Fbe.if_absent(fb: fbt) do |n|
          n.where = 'github'
          n.repository = repository
          n.issue = issue
          n.what = $judge
        end
      raise "Issue #{repo}##{issue} already closed" if nn.nil?
      nn.when = json[:closed_at] ? Time.parse(json[:closed_at].iso8601) : Time.now
      who = json.dig(:closed_by, :id)
      if who
        nn.who = who
      else
        nn.stale = 'who'
      end
      nn.details = "Apparently, #{Fbe.issue(nn)} has been #{nn.what.inspect}."
      $loog.info("It was found closed at #{Fbe.issue(nn)}")
    end
    issue
  end
end

Fbe.octo.print_trace!
