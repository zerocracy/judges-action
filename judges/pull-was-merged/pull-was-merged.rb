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
  as 'assignees-were-scanned'
  by "(agg
    (and
      (eq where 'github')
      (eq what 'pull-was-opened')
      (eq repository $repository)
      (gt issue $before)
      (empty
        (and
          (eq where $where)
          (eq repository $repository)
          (eq issue $issue)
          (or
            (eq what 'pull-was-closed')
            (eq what 'pull-was-merged')))))
    (min issue))"
  quota_aware
  repeats 100
  over(timeout: 5 * 60) do |repository, issue|
    repo = Fbe.octo.repo_name_by_id(repository)
    json = Fbe.octo.pull_request(repo, issue)
    next issue unless json[:state] == 'closed'
    nn =
      Fbe.if_absent do |n|
        n.where = 'github'
        n.repository = repository
        n.issue = issue
        n.when = Time.parse(json[:closed_at].iso8601)
        actor = Fbe.octo.issue(repo, f.issue)[:closed_by]
        n.who = actor[:id].to_i if actor
        action = json[:merged_at].nil? ? 'closed' : 'merged'
        n.what = "pull-was-#{action}"
        n.hoc = json[:additions] + json[:deletions]
        Jp.fill_fact_by_hash(n, Jp.comments_info(json))
        Jp.fill_fact_by_hash(n, Jp.fetch_workflows(json))
        n.branch = json[:head][:ref]
      end
    next issue if nn.nil?
    nn.details =
      "Apparently, #{Fbe.issue(nn)} has been '#{nn.what}' by #{Fbe.who(nn)}, " \
      "with #{nn.hoc} HoC and #{nn.comments} comments."
    issue
  end
end

Fbe.octo.print_trace!
