# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

# Judge that monitors issues which were closed.

require 'fbe/if_absent'
require 'fbe/issue'
require 'fbe/iterate'
require 'fbe/octo'
require 'fbe/who'

Fbe.iterate do
  as 'issues-were-scanned'
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
  over(timeout: ($options.timeout || 60) * 0.8) do |repository, issue|
    repo = Fbe.octo.repo_name_by_id(repository)
    begin
      json = Fbe.octo.issue(repo, issue)
    rescue Octokit::NotFound
      $loog.info("The issue #{repo}##{issue} doesn't exist")
      next issue
    end
    unless json[:state] == 'closed'
      $loog.debug("Issue #{repo}##{issue} is not closed: #{json[:state].inspect}")
      next issue
    end
    nn =
      Fbe.if_absent do |n|
        n.where = 'github'
        n.repository = repository
        n.issue = issue
        n.what = $judge
      end
    raise "Issue #{repo}##{issue} already closed" if nn.nil?
    nn.when = json[:closed_at] ? Time.parse(json[:closed_at].iso8601) : Time.now
    nn.who = json.dig(:closed_by, :id)
    nn.details = "Apparently, #{Fbe.issue(nn)} has been '#{nn.what}'."
    $loog.info("It was found closed at #{Fbe.issue(nn)}")
    issue
  end
end

Fbe.octo.print_trace!
