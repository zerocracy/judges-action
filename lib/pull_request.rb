# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/github_graph'
require 'fbe/octo'
require_relative 'humans'
require_relative 'jp'

Jp::NO_COMMENTS = {
  comments: 0,
  comments_to_code: 0,
  comments_by_author: 0,
  comments_by_reviewers: 0,
  comments_appreciated: 0,
  comments_resolved: 0
}.freeze

# @todo #2352:30min Forbidden is still swallowed as zero for reactions, resolved threads, runs and reviews

def Jp.comments_info(pr, repo: nil)
  repo = pr.dig(:base, :repo, :full_name) if repo.nil?
  if repo.nil?
    $loog.info("The repository of the pull ##{pr[:number]} is unknown, reporting no comments")
    return Jp::NO_COMMENTS
  end
  ccomments =
    begin
      Fbe.octo.pull_request_comments(repo, pr[:number])
    rescue Octokit::NotFound, Octokit::Deprecated => e
      $loog.info("PR comments not found for #{repo}##{pr[:number]}: #{e.message}")
      []
    rescue Octokit::Forbidden => e
      $loog.warn(
        "[#{$judge}] Access forbidden to PR comments for #{repo}##{pr[:number]} " \
        "(transient, will retry next cycle): #{e.class}: #{e.message}"
      )
      raise
    end
  icomments =
    begin
      Fbe.octo.issue_comments(repo, pr[:number])
    rescue Octokit::NotFound, Octokit::Deprecated => e
      $loog.info("Issue comments not found for #{repo}##{pr[:number]}: #{e.message}")
      []
    rescue Octokit::Forbidden => e
      $loog.warn(
        "[#{$judge}] Access forbidden to issue comments for #{repo}##{pr[:number]} " \
        "(transient, will retry next cycle): #{e.class}: #{e.message}"
      )
      raise
    end
  ccomments = Jp.human_comments(ccomments)
  icomments = Jp.human_comments(icomments)
  org, rname = repo.split('/')
  uid = pr.dig(:user, :id)
  {
    comments: ccomments.count + icomments.count,
    comments_to_code: ccomments.count,
    comments_by_author: ccomments.count { |c| c.dig(:user, :id) == uid } +
      icomments.count { |c| c.dig(:user, :id) == uid },
    comments_by_reviewers: ccomments.count { |c| c.dig(:user, :id) != uid } +
      icomments.count { |c| c.dig(:user, :id) != uid },
    comments_appreciated: Jp.count_appreciated_comments(pr, icomments, ccomments, repo:),
    comments_resolved:
      begin
        if Fbe.github_graph
          total = 0
          cursor = nil
          loop do
            data = Fbe.github_graph.query(
              <<~GRAPHQL
                {
                  repository(owner: "#{org}", name: "#{rname}") {
                    pullRequest(number: #{pr[:number]}) {
                      reviewThreads(first: 100#{%(, after: "#{cursor}") if cursor}) {
                        pageInfo {
                          hasNextPage
                          endCursor
                        }
                        nodes {
                          isResolved
                        }
                      }
                    }
                  }
                }
              GRAPHQL
            )&.to_h&.dig('repository', 'pullRequest', 'reviewThreads')
            break if data.nil? || data['nodes'].nil?
            total += data['nodes'].count { |n| n['isResolved'] }
            break unless data.dig('pageInfo', 'hasNextPage')
            cursor = data.dig('pageInfo', 'endCursor')
          end
          total
        else
          0
        end
      rescue GraphQL::Client::Error, Octokit::NotFound, Octokit::Deprecated => e
        $loog.info("Resolved conversations not available for #{repo}##{pr[:number]}: #{e.message}")
        0
      rescue Octokit::Forbidden => e
        $loog.warn(
          "[#{$judge}] Access forbidden to resolved conversations for #{repo}##{pr[:number]} " \
          "(transient, will retry next cycle): #{e.class}: #{e.message}"
        )
        0
      end
  }
end

Jp::APPRECIATIONS = %w[+1 heart hooray laugh rocket].freeze

def Jp.appreciated?(reaction, comment)
  return false if reaction.dig(:user, :id) == comment.dig(:user, :id)
  Jp::APPRECIATIONS.include?(reaction[:content].to_s)
end

def Jp.count_appreciated_comments(pr, issue_comments, code_comments, repo: nil)
  repo = pr.dig(:base, :repo, :full_name) if repo.nil?
  issue_comments.sum do |comment|
    Fbe.octo.issue_comment_reactions(repo, comment[:id])
      .count { |reaction| Jp.appreciated?(reaction, comment) }
  rescue Octokit::NotFound, Octokit::Deprecated => e
    $loog.info("Issue comment ##{comment[:id]} reactions don't exist in #{repo}: #{e.message}")
    0
  rescue Octokit::Forbidden => e
    $loog.warn(
      "Access forbidden to issue comment ##{comment[:id]} reactions in #{repo} " \
      "(transient, will retry next cycle): #{e.class}: #{e.message}"
    )
    0
  end + code_comments.sum do |comment|
    Fbe.octo.pull_request_review_comment_reactions(repo, comment[:id])
      .count { |reaction| Jp.appreciated?(reaction, comment) }
  rescue Octokit::NotFound, Octokit::Deprecated => e
    $loog.info("Code comment ##{comment[:id]} reactions don't exist in #{repo}: #{e.message}")
    0
  rescue Octokit::Forbidden => e
    $loog.warn(
      "Access forbidden to code comment ##{comment[:id]} reactions in #{repo} " \
      "(transient, will retry next cycle): #{e.class}: #{e.message}"
    )
    0
  end
end

def Jp.fetch_workflows(pr, repo: nil)
  succeeded = 0
  failed = 0
  repo = pr.dig(:base, :repo, :full_name) if repo.nil?
  if repo.nil?
    $loog.info("The repository of the pull ##{pr[:number]} is unknown, reporting no builds")
    return { succeeded_builds: 0, failed_builds: 0 }
  end
  begin
    entries = Fbe.octo.check_runs_for_ref(repo, pr.dig(:head, :sha))
  rescue Octokit::NotFound, Octokit::Deprecated => e
    $loog.info("Check runs not found for #{repo}@#{pr.dig(:head, :sha)}: #{e.message}")
    return { succeeded_builds: 0, failed_builds: 0 }
  rescue Octokit::Forbidden => e
    $loog.warn(
      "[#{$judge}] Access forbidden to check runs for #{repo}@#{pr.dig(:head, :sha)} " \
      "(transient, will retry next cycle): #{e.class}: #{e.message}"
    )
    raise
  end
  jobs = {}
  runs = {}
  (entries[:check_runs] || []).each do |run|
    next unless run.dig(:app, :slug) == 'github-actions'
    rid =
      jobs[run[:id]] ||=
        begin
          Fbe.octo.workflow_run_job(repo, run[:id])[:run_id]
        rescue Octokit::NotFound, Octokit::Deprecated => e
          $loog.info("Workflow run job not found for #{repo} job ##{run[:id]}: #{e.message}")
          nil
        rescue Octokit::Forbidden => e
          $loog.warn(
            "[#{$judge}] Access forbidden to workflow run job for #{repo} job ##{run[:id]} " \
            "(transient, will retry next cycle): #{e.class}: #{e.message}"
          )
          nil
        end
    next unless rid
    workflow =
      runs[rid] ||=
        begin
          Fbe.octo.workflow_run(repo, rid)
        rescue Octokit::NotFound, Octokit::Deprecated => e
          $loog.info("Workflow run not found for #{repo} run ##{rid}: #{e.message}")
          nil
        rescue Octokit::Forbidden => e
          $loog.warn(
            "[#{$judge}] Access forbidden to workflow run for #{repo} run ##{rid} " \
            "(transient, will retry next cycle): #{e.class}: #{e.message}"
          )
          nil
        end
    next unless workflow
    next unless workflow[:event] == 'pull_request'
    case workflow[:conclusion]
    when 'success'
      succeeded += 1
    when nil, 'skipped'
      next
    else
      failed += 1
    end
  end
  { succeeded_builds: succeeded, failed_builds: failed }
end

def Jp.count_suggestions(repo, issue, author, reviews = nil)
  found =
    begin
      reviews || Fbe.octo.pull_request_reviews(repo, issue)
    rescue Octokit::NotFound, Octokit::Deprecated => e
      $loog.info("Pull request reviews not found for #{repo}##{issue}: #{e.message}")
      []
    rescue Octokit::Forbidden => e
      $loog.warn(
        "[#{$judge}] Access forbidden to pull request reviews for #{repo}##{issue} " \
        "(transient, will retry next cycle): #{e.class}: #{e.message}"
      )
      []
    end
  found.sum do |review|
    next 0 if review.dig(:user, :id) == author
    comments =
      begin
        Fbe.octo.pull_request_review_comments(repo, issue, review[:id])
      rescue Octokit::NotFound, Octokit::Deprecated => e
        $loog.info("Review comments not found for #{repo}##{issue} review ##{review[:id]}: #{e.message}")
        []
      rescue Octokit::Forbidden => e
        $loog.warn(
          "[#{$judge}] Access forbidden to review comments for #{repo}##{issue} review ##{review[:id]} " \
          "(transient, will retry next cycle): #{e.class}: #{e.message}"
        )
        []
      end
    comments.count do |comment|
      comment.dig(:user, :id) != author && comment[:in_reply_to_id].nil? && Jp.suggests?(comment[:body])
    end
  end
end

def Jp.suggests?(body)
  body.to_s.match?(/^\s*```+suggestion\b/i)
end
