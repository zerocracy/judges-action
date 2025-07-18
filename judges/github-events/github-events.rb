# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

# Judge that monitors and records GitHub repository events into the factbase.
# Fetches events from GitHub repositories like push events, pull request events,
# issue events, release events, etc., and records them with detailed metadata
# in the factbase for analytics and tracking purposes.
#
# @note Limited to running for 5 minutes maximum to prevent excessive API usage
# @see https://github.com/yegor256/fbe/blob/master/lib/fbe/iterate.rb Implementation of Fbe.iterate
# @see https://github.com/yegor256/fbe/blob/master/lib/fbe/if_absent.rb Implementation of Fbe.if_absent

require 'tago'
require 'fbe/octo'
require 'fbe/github_graph'
require 'fbe/iterate'
require 'fbe/if_absent'
require 'fbe/who'
require 'fbe/issue'
require_relative '../../lib/fill_fact'
require_relative '../../lib/pull_request'

Fbe.iterate do
  as 'events-were-scanned'
  by '(plus 0 $before)'
  quota_aware

  def self.skip_event(json)
    t = Time.parse(json[:created_at].iso8601)
    $loog.debug(
      "Event ##{json[:id]} (#{json[:type]}) " \
      "in #{json[:repo][:name]} ignored (#{t.ago} ago)"
    )
    raise Factbase::Rollback
  end

  def self.fetch_tag(fact, repo)
    tag = fact&.all_properties&.include?('tag') ? fact.tag : nil
    if tag.nil? && fact&.all_properties&.include?('release_id')
      tag = Fbe.octo.release(
        "https://api.github.com/repos/#{repo}/releases/#{fact.release_id}"
      ).fetch(:tag_name, nil)
      $loog.debug("The release ##{fact.release_id} has this tag: #{tag.inspect}")
    end
    tag
  end

  def self.fetch_contributors(fact, repo)
    last = Fbe.fb.query("(and (eq repository #{fact.repository}) (eq what \"#{fact.what}\"))").each.to_a.last
    tag = fetch_tag(last, repo)
    contributors = Set.new
    if tag
      Fbe.octo.compare(repo, tag, fact.tag)[:commits].each do |commit|
        author_id = commit.dig(:author, :id)
        contributors << author_id if author_id
      end
    else
      Fbe.octo.contributors(repo).each do |contributor|
        contributors << contributor[:id]
      end
    end
    $loog.debug("The repository ##{fact.repository} has #{contributors.count} contributors")
    contributors.to_a
  end

  def self.fetch_release_info(fact, repo)
    last = Fbe.fb.query("(and (eq repository #{fact.repository}) (eq what \"#{fact.what}\"))").each.to_a.last
    tag = fetch_tag(last, repo)
    tag ||= find_first_commit(repo)[:sha]
    info = {}
    Fbe.octo.compare(repo, tag, fact.tag).then do |json|
      info[:commits] = json[:total_commits]
      info[:hoc] = json[:files].sum { |f| f[:changes] }
      info[:last_commit] = json[:commits].first[:sha]
    end
    $loog.debug("The repository ##{fact.repository} has this: #{info.inspect}")
    info
  end

  def self.find_first_commit(repo)
    commits = Fbe.octo.commits(repo)
    last = commits.last
    while commits.size != 1
      commits = Fbe.octo.commits(repo, sha: last[:sha])
      last = commits.last
    end
    $loog.debug("The repo ##{repo} has this last commit: #{last}")
    last
  end

  def self.issue_seen_already?(fact)
    Fbe.fb.query(
      "(and (eq repository #{fact.repository}) " \
      '(eq where "github") ' \
      "(not (eq event_id #{fact.event_id}))" \
      "(eq what \"#{fact.what}\") " \
      "(eq issue #{fact.issue}))"
    ).each.any?
  end

  def self.fill_up_event(fact, json)
    fact.when = Time.parse(json[:created_at].iso8601)
    fact.event_type = json[:type]
    fact.repository = json[:repo][:id].to_i
    fact.who = json[:actor][:id].to_i if json[:actor]
    rname = Fbe.octo.repo_name_by_id(fact.repository)

    case json[:type]
    when 'PushEvent'
      fact.what = 'git-was-pushed'
      fact.push_id = json[:payload][:push_id]
      fact.ref = json[:payload][:ref]
      fact.commit = json[:payload][:head]
      fact.default_branch = Fbe.octo.repository(rname)[:default_branch]
      fact.to_master = fact.default_branch == fact.ref.split('/')[2] ? 1 : 0
      if fact.to_master.zero?
        $loog.debug("Push #{fact.commit} has been made to non-default branch '#{fact.default_branch}', ignoring it")
        skip_event(json)
      end
      pulls = Fbe.octo.commit_pulls(rname, fact.commit)
      unless pulls.empty?
        $loog.debug("Push #{fact.commit} has been made inside #{pulls.size} pull request(s), ignoring it")
        skip_event(json)
      end
      fact.details =
        "A new Git push ##{json[:payload][:push_id]} has arrived to #{rname}, " \
        "made by #{Fbe.who(fact)} (default branch is '#{fact.default_branch}'), " \
        'not associated with any pull request.'
      $loog.debug("New PushEvent ##{json[:payload][:push_id]} recorded")

    when 'PullRequestEvent'
      pl = json[:payload][:pull_request]
      fact.issue = pl[:number]
      case json[:payload][:action]
      when 'opened'
        fact.what = 'pull-was-opened'
        fact.branch = pl[:head][:ref]
        fact.details =
          "The pull request #{Fbe.issue(fact)} has been opened by #{Fbe.who(fact)}."
        $loog.debug("New PR #{Fbe.issue(fact)} opened by #{Fbe.who(fact)}")
      when 'closed'
        fact.what = "pull-was-#{pl[:merged_at].nil? ? 'closed' : 'merged'}"
        fact.hoc = pl[:additions] + pl[:deletions]
        Jp.fill_fact_by_hash(fact, Jp.comments_info(pl))
        Jp.fill_fact_by_hash(fact, Jp.fetch_workflows(pl))
        fact.branch = pl[:head][:ref]
        fact.details =
          "The pull request #{Fbe.issue(fact)} " \
          "has been #{json[:payload][:action]} by #{Fbe.who(fact)}, " \
          "with #{fact.hoc} HoC and #{fact.comments} comments."
        skip_event(json) if issue_seen_already?(fact)
        $loog.debug("PR #{Fbe.issue(fact)} closed by #{Fbe.who(fact)}")
      else
        skip_event(json)
      end

    when 'PullRequestReviewEvent'
      case json[:payload][:action]
      when 'created'
        skip_event(json) if json[:payload][:pull_request][:user][:id].to_i == fact.who
        if Fbe.fb.query(
          "(and (eq repository #{fact.repository}) " \
          '(eq what "pull-was-reviewed") ' \
          "(eq who #{fact.who}) " \
          "(eq issue #{json[:payload][:pull_request][:number]}))"
        ).each.to_a.last
          skip_event(json)
        end
        skip_event(json) unless json[:payload][:review][:state] == 'approved'

        fact.issue = json[:payload][:pull_request][:number]
        fact.what = 'pull-was-reviewed'
        pull = Fbe.octo.pull_request(rname, fact.issue)
        fact.hoc = pull[:additions] + pull[:deletions]
        fact.comments = pull[:comments] + pull[:review_comments]
        fact.review_comments = pull[:review_comments]
        fact.commits = pull[:commits]
        fact.files = pull[:changed_files]
        fact.details =
          "The pull request #{Fbe.issue(fact)} " \
          "has been reviewed by #{Fbe.who(fact)} " \
          "with #{fact.hoc} HoC and #{fact.comments} comments."
        $loog.debug("PR #{Fbe.issue(fact)} was reviewed by #{Fbe.who(fact)}")
      else
        skip_event(json)
      end

    when 'IssuesEvent'
      fact.issue = json[:payload][:issue][:number]
      case json[:payload][:action]
      when 'closed'
        fact.what = 'issue-was-closed'
        fact.details =
          "The issue #{Fbe.issue(fact)} has been closed by #{Fbe.who(fact)}."
        $loog.debug("Issue #{Fbe.issue(fact)} closed by #{Fbe.who(fact)}")
      when 'opened'
        fact.what = 'issue-was-opened'
        fact.details =
          "The issue #{Fbe.issue(fact)} has been opened by #{Fbe.who(fact)}."
        $loog.debug("Issue #{Fbe.issue(fact)} opened by #{Fbe.who(fact)}")
      else
        skip_event(json)
      end
      skip_event(json) if issue_seen_already?(fact)

    when 'IssueCommentEvent'
      skip_event(json) # this event is not needed for now
      fact.issue = json[:payload][:issue][:number]
      case json[:payload][:action]
      when 'created'
        fact.what = 'comment-was-posted'
        fact.comment_id = json[:payload][:comment][:id]
        fact.comment_body = json[:payload][:comment][:body]
        fact.who = json[:payload][:comment][:user][:id]
        fact.details =
          "A new comment ##{json[:payload][:comment][:id]} has been posted " \
          "to #{Fbe.issue(fact)} by #{Fbe.who(fact)}."
        $loog.debug("Issue comment posted to #{Fbe.issue(fact)} by #{Fbe.who(fact)}")
      else
        skip_event(json)
      end

    when 'ReleaseEvent'
      fact.release = json[:payload][:release][:id]
      fact.tag = json[:payload][:release][:tag_name]
      case json[:payload][:action]
      when 'published'
        fact.what = 'release-published'
        fact.who = json[:payload][:release][:author][:id]
        fetch_contributors(fact, rname).each { |c| fact.contributors = c }
        Jp.fill_fact_by_hash(
          fact, fetch_release_info(fact, rname)
        )
        fact.details =
          "A new release '#{json[:payload][:release][:name]}' has been published " \
          "in #{rname} by #{Fbe.who(fact)}."
        $loog.debug("Release published by #{Fbe.who(fact)}")
      else
        skip_event(json)
      end

    when 'CreateEvent'
      case json[:payload][:ref_type]
      when 'tag'
        fact.what = 'tag-was-created'
        fact.tag = json[:payload][:ref]
        fact.details =
          "A new tag '#{fact.tag}' has been created " \
          "in #{rname} by #{Fbe.who(fact)}."
        $loog.debug("Tag #{fact.tag.inspect} created by #{Fbe.who(fact)}")
      else
        skip_event(json)
      end

    else
      skip_event(json)
    end
  rescue Octokit::Forbidden
    who =
      begin
        "@#{Fbe.octo.user[:login]}"
      rescue Octokit::Forbidden
        'You'
      end
    raise "#{who} doesn't have access to the #{rname} repository, maybe it's private"
  end

  over(timeout: 5 * 60) do |repository, latest|
    rname = Fbe.octo.repo_name_by_id(repository)
    $loog.debug("Starting to scan repository #{rname} (##{repository}), the latest event_id was ##{latest}...")
    id = nil
    total = 0
    detected = 0
    first = nil
    rstart = Time.now
    Fbe.octo.repository_events(repository).each_with_index do |json, idx|
      if !$options.max_events.nil? && idx >= $options.max_events
        $loog.debug("Already scanned #{idx} events in #{rname}, stop now")
        break
      end
      total += 1
      id = json[:id].to_i
      first = id if first.nil?
      if id <= latest
        $loog.debug("The event_id ##{id} (no.#{idx}) is not larger than ##{latest}, good stop in #{json[:repo][:name]}")
        break
      end
      Fbe.fb.txn do |fbt|
        f =
          Fbe.if_absent(fb: fbt) do |n|
            n.where = 'github'
            n.event_id = json[:id].to_i
          end
        if f.nil?
          $loog.debug("The event ##{id} just detected is already in the factbase")
        else
          fill_up_event(f, json)
          $loog.info("Detected new event_id ##{id} (no.#{idx}) in #{json[:repo][:name]}: #{json[:type]}")
          detected += 1
        end
      end
    end
    $loog.info("In #{rname}, detected #{detected} events out of #{total} scanned in #{rstart.ago}")
    if id.nil?
      $loog.debug("No events found in #{rname} in #{rstart.ago}, the latest event_id remains ##{latest}")
      latest
    elsif id <= latest || latest.zero?
      $loog.debug("Finished scanning #{rname} correctly in #{rstart.ago}, next time will scan until ##{first}")
      first
    else
      $loog.debug("Scanning of #{rname} wasn't completed in #{rstart.ago}, next time will try again until ##{latest}")
      latest
    end
  end
end

Fbe.octo.print_trace!
