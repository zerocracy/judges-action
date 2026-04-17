# frozen_string_literal: true

require 'fbe/github_graph'
# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require_relative 'jp'

def Jp.comments_info(pr, repo: nil)
  repo = pr.dig(:base, :repo, :full_name) if repo.nil?
  return {} if repo.nil?
  ccomments = Fbe.octo.pull_request_comments(repo, pr[:number])
  icomments = Fbe.octo.issue_comments(repo, pr[:number])
  org, rname = repo.split('/')
  uid = pr.dig(:user, :id)
  {
    comments: (pr[:comments] || 0) + (pr[:review_comments] || 0),
    comments_to_code: ccomments.count,
    comments_by_author: ccomments.count { |c| c.dig(:user, :id) == uid } +
      icomments.count { |c| c.dig(:user, :id) == uid },
    comments_by_reviewers: ccomments.count { |c| c.dig(:user, :id) != uid } +
      icomments.count { |c| c.dig(:user, :id) != uid },
    comments_appreciated: Jp.count_appreciated_comments(pr, icomments, ccomments, repo:),
    comments_resolved: Fbe.github_graph.resolved_conversations(org, rname, pr[:number]).count
  }
end

def Jp.count_appreciated_comments(pr, issue_comments, code_comments, repo: nil)
  repo = pr.dig(:base, :repo, :full_name) if repo.nil?
  issued =
    issue_comments.sum do |comment|
      Fbe.octo.issue_comment_reactions(repo, comment[:id])
         .count { |reaction| reaction[:user][:id] != comment[:user][:id] }
    end
  coded =
    code_comments.sum do |comment|
      Fbe.octo.pull_request_review_comment_reactions(repo, comment[:id])
         .count { |reaction| reaction[:user][:id] != comment[:user][:id] }
    end
  issued + coded
end

def Jp.fetch_workflows(pr, repo: nil)
  succeeded = 0
  failed = 0
  repo = pr.dig(:base, :repo, :full_name) if repo.nil?
  return {} if repo.nil?
  Fbe.octo.check_runs_for_ref(repo, pr.dig(:head, :sha))[:check_runs].each do |run|
    next unless run[:app][:slug] == 'github-actions'
    workflow = Fbe.octo.workflow_run(repo, Fbe.octo.workflow_run_job(repo, run[:id])[:run_id])
    next unless workflow[:event] == 'pull_request'
    case workflow[:conclusion]
    when 'success'
      succeeded += 1
    when 'failure'
      failed += 1
    end
  end
  { succeeded_builds: succeeded, failed_builds: failed }
end

def Jp.count_suggestions(repo, issue, author)
  Fbe.octo.pull_request_reviews(repo, issue).sum do |review|
    next 0 if review.dig(:user, :id) == author
    Fbe.octo.pull_request_review_comments(repo, issue, review[:id]).sum do |comment|
      next 0 if comment.dig(:user, :id) == author || !comment[:in_reply_to_id].nil?
      1
    end
  end
end
