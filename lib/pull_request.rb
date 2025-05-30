# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/github_graph'
require_relative 'jp'

# Collects number of many kind of comments from pull request
#
# @param [Sawyer::Resource] pr The pull request
# @return [Hash] number of many kind of comments
def Jp.comments_info(pr)
  code_comments = Fbe.octo.pull_request_comments(pr[:base][:repo][:full_name], pr[:number])
  issue_comments = Fbe.octo.issue_comments(pr[:base][:repo][:full_name], pr[:number])
  {
    comments: pr[:comments] + pr[:review_comments],
    comments_to_code: code_comments.count,
    comments_by_author: code_comments.count { |comment| comment[:user][:id] == pr[:user][:id] } +
      issue_comments.count { |comment| comment[:user][:id] == pr[:user][:id] },
    comments_by_reviewers: code_comments.count { |comment| comment[:user][:id] != pr[:user][:id] } +
      issue_comments.count { |comment| comment[:user][:id] != pr[:user][:id] },
    comments_appreciated: Jp.count_appreciated_comments(pr, issue_comments, code_comments),
    comments_resolved: Fbe.github_graph.resolved_conversations(
      pr[:base][:repo][:full_name].split('/').first, pr[:base][:repo][:name], pr[:number]
    ).count
  }
end

# Calculate total number of reactions on comments of issue and pull request excluding the author of the comment
#
# @param [Sawyer::Resource] pr The pull request
# @param [Array<Sawyer::Resource>] issue_comments Array of comments from issue
# @param [Array<Sawyer::Resource>] code_comments Array of comments for pull request
# @return [Integer] sum of the number of reactions to comments issue and pull request comments
def Jp.count_appreciated_comments(pr, issue_comments, code_comments)
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

# Fetch info about success and failure builds from pull request
#
# @param [Sawyer::Resource] pr The pull request
# @return [Hash] count of success/failure builds
def Jp.fetch_workflows(pr)
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
