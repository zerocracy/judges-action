# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/github_graph'
require_relative 'jp'

# Collects number of many kind of comments from pull request
#
# @param [Sawyer::Resource] pr The pull request
# @return [Hash] number of many kind of comments
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

# Calculate total number of reactions on comments of issue and pull request excluding the author of the comment
#
# @param [Sawyer::Resource] pr The pull request
# @param [Array<Sawyer::Resource>] issue_comments Array of comments from issue
# @param [Array<Sawyer::Resource>] code_comments Array of comments for pull request
# @return [Integer] sum of the number of reactions to comments issue and pull request comments
def Jp.count_appreciated_comments(pr, issue_comments, code_comments, repo: nil)
  repo = pr.dig(:base, :repo, :full_name) if repo.nil?
  issue_appreciations =
    issue_comments.sum do |comment|
      Fbe.octo.issue_comment_reactions(repo, comment[:id])
         .count { |reaction| reaction[:user][:id] != comment[:user][:id] }
    end
  code_appreciations =
    code_comments.sum do |comment|
      Fbe.octo.pull_request_review_comment_reactions(repo, comment[:id])
         .count { |reaction| reaction[:user][:id] != comment[:user][:id] }
    end
  issue_appreciations + code_appreciations
end

# Fetch info about success and failure builds from pull request
#
# @param [Sawyer::Resource] pr The pull request
# @return [Hash] count of success/failure builds
def Jp.fetch_workflows(pr, repo: nil)
  succeeded_builds = 0
  failed_builds = 0
  repo = pr.dig(:base, :repo, :full_name) if repo.nil?
  return {} if repo.nil?
  Fbe.octo.check_runs_for_ref(repo, pr.dig(:head, :sha))[:check_runs].each do |run|
    next unless run[:app][:slug] == 'github-actions'
    workflow = Fbe.octo.workflow_run(
      repo,
      Fbe.octo.workflow_run_job(repo, run[:id])[:run_id]
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

# Count code suggestions for pull request.
# Author suggestions are not taken into account
#
# @param [String] repo Github repository (e.g.: 'org/repo')
# @param [Integer] issue Number ID of the pull request
# @param [Integer] author Github user ID, who create pull request
# @return [Integer] count of suggestions
def Jp.count_suggestions(repo, issue, author)
  Fbe.octo.pull_request_reviews(repo, issue).sum do |review|
    next 0 if review.dig(:user, :id) == author
    Fbe.octo.pull_request_review_comments(repo, issue, review[:id]).sum do |comment|
      next 0 if comment.dig(:user, :id) == author || !comment[:in_reply_to_id].nil?
      1
    end
  end
end
