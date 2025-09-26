# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

# Judge that monitors pulls which were closed or merged.

require 'fbe/conclude'
require 'fbe/delete'
require 'fbe/github_graph'
require 'fbe/issue'
require 'fbe/octo'
require 'fbe/overwrite'
require 'fbe/who'
require_relative '../../lib/fill_fact'
require_relative '../../lib/issue_was_lost'
require_relative '../../lib/pull_request'

Fbe.iterate do
  as 'merges_were_scanned'
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
      (absent tombstone)
      (absent done)
      (eq where 'github'))
    (min issue))"
  repeats 50
  over do |repository, issue|
    repo = Fbe.octo.repo_name_by_id(repository)
    json =
      begin
        Fbe.octo.pull_request(repo, issue)
      rescue Octokit::NotFound => e
        $loog.info("The pull ##{f.issue} doesn't exist in #{repo}: #{e.message}")
        Jp.issue_was_lost('github', repository, issue)
        next issue
      end
    unless json[:state] == 'closed'
      $loog.debug("Pull #{repo}##{issue} is not closed: #{json[:state].inspect}")
      next issue
    end
    Fbe.fb.txn do |fbt|
      nn =
        Fbe.if_absent(fb: fbt) do |n|
          n.issue = issue
          n.what = "pull-was-#{json[:merged_at].nil? ? 'closed' : 'merged'}"
          n.repository = repository
          n.where = 'github'
        end
      raise "Pull already merged in #{repo}##{issue}" if nn.nil?
      nn.hoc = json[:additions] + json[:deletions]
      nn.files = json[:changed_files] if json[:changed_files]
      nn.branch = json[:head][:ref]
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
    end
    issue
  end
end

Fbe.octo.print_trace!
