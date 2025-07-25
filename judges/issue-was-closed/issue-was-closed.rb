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
      (eq where 'github')
      (eq what 'issue-was-opened')
      (eq repository $repository)
      (gt issue $before)
      (empty
        (and
          (eq where $where)
          (eq repository $repository)
          (eq issue $issue)
          (eq what 'issue-was-closed'))))
    (min issue))"
  quota_aware
  repeats 100
  over(timeout: 5 * 60) do |repository, issue|
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
        n.what = 'issue-was-closed'
      end
    next issue if nn.nil?
    nn.when = json[:closed_at] ? Time.parse(json[:closed_at].iso8601) : Time.now
    nn.who = json.dig(:closed_by, :id)
    nn.details = "Apparently, #{Fbe.issue(nn)} has been '#{nn.what}'."
    issue
  end
end

Fbe.octo.print_trace!
