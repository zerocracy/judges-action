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

Fbe.conclude do
  quota_aware
  on "(and (eq where 'github') (eq what 'pull-was-opened'))"

  def self.fill_fact_by_hash(fact, hash)
    hash.each do |prop, value|
      fact.send(:"#{prop}=", value)
    end
  end

  def self.comments_info(pr)
    code_comments = Fbe.octo.pull_request_comments(pr[:base][:repo][:full_name], pr[:number])
    issue_comments = Fbe.octo.issue_comments(pr[:base][:repo][:full_name], pr[:number])
    {
      comments: pr[:comments] + pr[:review_comments],
      comments_to_code: code_comments.count,
      comments_by_author: code_comments.count { |comment| comment[:user][:id] == pr[:user][:id] } +
        issue_comments.count { |comment| comment[:user][:id] == pr[:user][:id] },
      comments_by_reviewers: code_comments.count { |comment| comment[:user][:id] != pr[:user][:id] } +
        issue_comments.count { |comment| comment[:user][:id] != pr[:user][:id] },
      comments_appreciated: count_appreciated_comments(pr, issue_comments, code_comments),
      comments_resolved: Fbe.github_graph.resolved_conversations(
        pr[:base][:repo][:full_name].split('/').first, pr[:base][:repo][:name], pr[:number]
      ).count
    }
  end

  def self.count_appreciated_comments(pr, issue_comments, code_comments)
    issue_appreciations =
      issue_comments.sum do |comment|
        Fbe.octo.issue_comment_reactions(pr[:base][:repo][:full_name], comment[:id])
           .count { |reaction| reaction[:user][:id] != comment[:user][:id] }
      end
    code_appreciations =
      code_comments.sum do |comment|
        Fbe.octo.pull_request_review_comment_reactions(pr[:base][:repo][:full_name], comment[:id])
           .count { |reaction| reaction[:user][:id] != comment[:user][:id] }
      end
    issue_appreciations + code_appreciations
  end

  def self.fetch_workflows(pr)
    succeeded_builds = 0
    failed_builds = 0
    Fbe.octo.check_runs_for_ref(pr[:base][:repo][:full_name], pr[:head][:sha])[:check_runs].each do |run|
      next unless run[:app][:slug] == 'github-actions'
      workflow = Fbe.octo.workflow_run(
        pr[:base][:repo][:full_name],
        Fbe.octo.workflow_run_job(pr[:base][:repo][:full_name], run[:id])[:run_id]
      )
      next unless workflow[:event] == 'pull_request'
      case workflow[:conclusion]
      when 'success'
        succeeded_builds += 1
      when 'failure'
        failed_builds += 1
      end
    end
    { succeeded_builds:, failed_builds: }
  end

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
    next if f['not_merged'] && (f['not_merged'].last + (24 * 60 * 60) > now)
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
          fill_fact_by_hash(fact, comments_info(json))
          fill_fact_by_hash(fact, fetch_workflows(json))
          fact.branch = json[:head][:ref]
          fact.details =
            "The pull request #{Fbe.issue(fact)} " \
            "has been #{action} by #{Fbe.who(fact)}, " \
            "with #{fact.hoc} HoC and #{fact.comments} comments."
        end
      end
    else
      f.not_merged = now
    end
  end
end
