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

Fbe.conclude do
  quota_aware
  on "(and (eq where 'github') (eq what 'pull-was-opened'))"

  consider do |f|
    now = Time.now.utc
    next unless Fbe.fb.query(
      "(and
         (eq where 'github')
         (eq repository #{f.repository})
         (eq issue #{f.issue})
         (or
           (eq what 'pull-was-closed')
           (eq what 'pull-was-merged')))"
    ).each.to_a.first.nil?
    next if f['not_merged'] && (f.not_merged + (24 * 60 * 60) > now)
    rname = Fbe.octo.repo_name_by_id(f.repository)
    json = Fbe.octo.pull_request(rname, f.issue)
    if json[:state] == 'closed'
      Fbe.delete(f, 'not_merged') if f['not_merged']
      Fbe.fb.txn do |fbt|
        fbt.insert.then do |fact|
          fact.where = 'github'
          fact.when = Time.parse(json[:closed_at].iso8601)
          fact.repository = json[:base][:repo][:id].to_i
          actor = Fbe.octo.issue(rname, f.issue)[:closed_by]
          fact.who = actor[:id].to_i if actor
          action = json[:merged_at].nil? ? 'closed' : 'merged'
          fact.what = "pull-was-#{action}"
          fact.issue = json[:number]
          fact.hoc = json[:additions] + json[:deletions]
          Jp.fill_fact_by_hash(fact, Jp.comments_info(json))
          Jp.fill_fact_by_hash(fact, Jp.fetch_workflows(json))
          fact.branch = json[:head][:ref]
          fact.details =
            "Apparently, pull request #{Fbe.issue(fact)} " \
            "has been #{action} by #{Fbe.who(fact)}, " \
            "with #{fact.hoc} HoC and #{fact.comments} comments."
        end
      end
    else
      Fbe.overwrite(f, 'not_merged', now)
    end
  end
end

Fbe.octo.print_trace!
