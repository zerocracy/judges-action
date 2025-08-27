# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

# Judge that monitors pulls which were closed or merged.

require 'fbe/conclude'
require 'fbe/octo'
require 'fbe/github_graph'
require 'fbe/who'
require 'fbe/issue'
require 'fbe/delete'
require 'fbe/overwrite'
require_relative '../../lib/fill_fact'
require_relative '../../lib/pull_request'

Fbe.iterate do
  as 'merges-were-scanned'
  by "(agg
    (and
      (eq repository $repository)
      (gt issue $before)
      (empty
        (and
          (eq repository $repository)
          (eq issue $issue)
          (eq what 'pull-was-closed')
          (eq where $where)))
      (empty
        (and
          (eq repository $repository)
          (eq issue $issue)
          (eq what 'pull-was-merged')
          (eq where $where)))
      (or
        (eq what 'pull-was-reviewed')
        (eq what 'pull-was-opened')
        (eq what 'code-was-contributed')
        (eq what 'code-was-reviewed')
        (eq what 'code-contribution-was-rewarded')
        (eq what 'code-review-was-rewarded'))
      (absent stale)
      (eq where 'github'))
    (min issue))"
  quota_aware
  repeats 50
  over(timeout: ($options.timeout || 60) * 0.8) do |repository, issue|
    repo = Fbe.octo.repo_name_by_id(repository)
    json = Fbe.octo.pull_request(repo, issue)
    unless json[:state] == 'closed'
      $loog.debug("Pull #{repo}##{issue} is not closed: #{json[:state].inspect}")
      next issue
    end
    nn =
      Fbe.if_absent do |n|
        n.where = 'github'
        n.repository = repository
        n.issue = issue
        n.what = "pull-was-#{json[:merged_at].nil? ? 'closed' : 'merged'}"
        n.hoc = json[:additions] + json[:deletions]
        n.branch = json[:head][:ref]
      end
    raise "Pull already merged in #{repo}##{issue}" if nn.nil?
    Jp.fill_fact_by_hash(nn, Jp.comments_info(json))
    Jp.fill_fact_by_hash(nn, Jp.fetch_workflows(json))
    actor = Fbe.octo.issue(repo, issue)[:closed_by]
    if actor
      nn.who = actor[:id].to_i
    else
      nn.stale = 'who'
    end
    nn.when = json[:closed_at] ? Time.parse(json[:closed_at].iso8601) : Time.now
    nn.details = "Apparently, #{Fbe.issue(nn)} has been '#{nn.what}'."
    $loog.debug("Just found out that #{Fbe.issue(nn)} has been '#{nn.what}'")
    issue
  end
end

Fbe.octo.print_trace!
