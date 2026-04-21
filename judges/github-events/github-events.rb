# frozen_string_literal: true

require 'fbe/github_graph'
require 'fbe/if_absent'
require 'fbe/issue'
require 'fbe/iterate'
require 'fbe/octo'
require 'fbe/tombstone'
require 'fbe/who'
# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'tago'
require_relative '../../lib/fill_fact'
require_relative '../../lib/pull_request'
require_relative '../../lib/supervision'

Fbe.iterate do
  as 'events_were_scanned'
  by '(plus 0 $before)'
  def self.skip(json)
    t = Time.parse(json[:created_at].iso8601)
    $loog.debug("Event ##{json[:id]} (#{json[:type]}) in #{json[:repo][:name]} ignored (#{t.ago} ago)")
    raise(Factbase::Rollback)
  end

  def self.tag(fact, repo)
    tag = fact&.all_properties&.include?('tag') ? fact.tag : nil
    if tag.nil? && fact&.all_properties&.include?('release_id')
      tag = Fbe.octo.release("https://api.github.com/repos/#{repo}/releases/#{fact.release_id}").fetch(:tag_name, nil)
      $loog.debug("The release ##{fact.release_id} has this tag: #{tag.inspect}")
    end
    tag
  end

  def self.contributors(fact, repo)
    last = Fbe.fb.query("(and (eq repository #{fact.repository}) (eq what \"#{fact.what}\"))").each.last
    since = tag(last, repo)
    list = Set.new
    if since
      Fbe.octo.compare(repo, since, fact.tag)[:commits].each do |commit|
        author = commit.dig(:author, :id)
        list << author if author
      end
    else
      Fbe.octo.contributors(repo).each do |contributor|
        list << contributor[:id]
      end
    end
    $loog.debug("The repository ##{fact.repository} has #{list.count} contributors")
    list.to_a
  end

  def self.info(fact, repo)
    last = Fbe.fb.query("(and (eq repository #{fact.repository}) (eq what \"#{fact.what}\"))").each.last
    since = tag(last, repo)
    since ||= earliest(repo)[:sha]
    info = {}
    begin
      Fbe.octo.compare(repo, since, fact.tag).then do |json|
        return info if json.nil?
        info[:commits] = json[:total_commits]
        info[:hoc] = json[:files].sum { |f| f[:changes] }
        info[:last_commit] = json[:commits].first[:sha]
      end
    rescue Octokit::NotFound
      $loog.info("Compare API returned 404 for #{repo} between #{since} and #{fact.tag}")
    end
    $loog.debug("The repository ##{fact.repository} has this: #{info.inspect}")
    info
  end

  def self.earliest(repo)
    commits = Fbe.octo.commits(repo)
    last = commits.last
    while commits.size != 1
      commits = Fbe.octo.commits(repo, sha: last[:sha])
      last = commits.last
    end
    $loog.debug("The repo ##{repo} has this last commit: #{last}")
    last
  end

  def self.seen?(fact)
    Fbe.fb.query(
      "(and
        (eq repository #{fact.repository})
        (eq issue #{fact.issue})
        (eq what '#{fact.what}')
        (not (eq event_id #{fact.event_id}))
        (eq where 'github'))"
    ).each.any?
  end

  def self.fill(fact, json)
    fact.when = Time.parse(json[:created_at].iso8601)
    fact.event_type = json[:type]
    fact.repository = Integer(json[:repo][:id])
    fact.who = Integer(json[:actor][:id]) if json[:actor]
    rname = Fbe.octo.repo_name_by_id(fact.repository)
    case json[:type]
    when 'PushEvent'
      fact.what = 'git-was-pushed'
      fact.push_id = json[:payload][:push_id]
      fact.ref = json[:payload][:ref]
      fact.commit = json[:payload][:head]
      repo = Fbe.octo.repository(rname)
      fact.default_branch = repo[:default_branch]
      fact.to_master = fact.default_branch == fact.ref.split('/')[2] ? 1 : 0
      fact.by_owner = 1 if repo.dig(:owner, :id) == fact.who
      if fact.to_master.zero?
        $loog.debug("Push #{fact.commit} to non-default branch #{fact.default_branch.inspect}, ignoring it")
        skip(json)
      end
      pulls = Fbe.octo.commit_pulls(rname, fact.commit)
      unless pulls.empty?
        $loog.debug("Push #{fact.commit} inside #{pulls.size} pull request(s), ignoring it")
        skip(json)
      end
      fact.details =
        "A new Git push ##{json[:payload][:push_id]} has arrived to #{rname}, " \
        "made by #{Fbe.who(fact)} (default branch is #{fact.default_branch.inspect}), " \
        'not associated with any pull request.'
      $loog.debug("New PushEvent ##{json[:payload][:push_id]} recorded")
    when 'PullRequestEvent'
      fact.issue = json.dig(:payload, :pull_request, :number)
      case json[:payload][:action]
      when 'opened'
        fact.what = 'pull-was-opened'
        fact.branch = json.dig(:payload, :pull_request, :head, :ref)
        fact.details = "The pull request #{Fbe.issue(fact)} has been opened by #{Fbe.who(fact)}."
        $loog.debug("New PR #{Fbe.issue(fact)} opened by #{Fbe.who(fact)}")
      when 'closed'
        pl =
          begin
            Fbe.octo.pull_request(rname, fact.issue)
          rescue Octokit::NotFound
            $loog.warn("The pull request ##{fact.issue} doesn't exist in #{rname}")
            nil
          end
        skip(json) if pl.nil?
        fact.what = "pull-was-#{pl[:merged_at].nil? ? 'closed' : 'merged'}"
        fact.hoc = (pl[:additions] || 0) + (pl[:deletions] || 0)
        fact.files = pl[:changed_files] unless pl[:changed_files].nil?
        Jp.fill_fact_by_hash(fact, Jp.comments_info(pl, repo: rname))
        Jp.fill_fact_by_hash(fact, Jp.fetch_workflows(pl, repo: rname))
        fact.branch = pl[:head][:ref]
        review =
          begin
            Fbe.octo.pull_request_reviews(rname, fact.issue).first
          rescue Octokit::NotFound
            $loog.warn("The pull request ##{fact.issue} doesn't exist in #{rname}")
            nil
          end
        fact.review = review[:submitted_at] if review
        author = pl.dig(:user, :id)
        fact.suggestions = Jp.count_suggestions(rname, fact.issue, author) if author
        fact.details =
          "The pull request #{Fbe.issue(fact)} " \
          "has been #{json[:payload][:action]} by #{Fbe.who(fact)}, " \
          "with #{fact.hoc} HoC and #{fact.comments} comments."
        skip(json) if seen?(fact)
        $loog.debug("PR #{Fbe.issue(fact)} closed by #{Fbe.who(fact)}")
      else
        skip(json)
      end
    when 'PullRequestReviewEvent'
      fact.issue = json.dig(:payload, :pull_request, :number)
      case json[:payload][:action]
      when 'created'
        pull = Fbe.octo.pull_request(rname, fact.issue)
        skip(json) if Integer(pull.dig(:user, :id)) == fact.who
        if Fbe.fb.query(
          "(and (eq repository #{fact.repository}) " \
          '(eq what "pull-was-reviewed") ' \
          "(eq who #{fact.who}) " \
          "(eq issue #{fact.issue}))"
        ).each.last
          skip(json)
        end
        skip(json) unless json.dig(:payload, :review, :state) == 'approved'
        fact.what = 'pull-was-reviewed'
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
        skip(json)
      end
    when 'IssuesEvent'
      fact.issue = json[:payload][:issue][:number]
      case json[:payload][:action]
      when 'closed'
        fact.what = 'issue-was-closed'
        fact.details = "The issue #{Fbe.issue(fact)} has been closed by #{Fbe.who(fact)}."
        $loog.debug("Issue #{Fbe.issue(fact)} closed by #{Fbe.who(fact)}")
      when 'opened'
        fact.what = 'issue-was-opened'
        fact.details = "The issue #{Fbe.issue(fact)} has been opened by #{Fbe.who(fact)}."
        $loog.debug("Issue #{Fbe.issue(fact)} opened by #{Fbe.who(fact)}")
      else
        skip(json)
      end
      skip(json) if seen?(fact)
    when 'IssueCommentEvent'
      skip(json)
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
        skip(json)
      end
    when 'ReleaseEvent'
      fact.release = json[:payload][:release][:id]
      fact.tag = json[:payload][:release][:tag_name]
      case json[:payload][:action]
      when 'published'
        fact.what = 'release-published'
        if fact.all_properties.include?('who') && fact.who != json[:payload][:release][:author][:id]
          Fbe.overwrite(fact, 'who', json[:payload][:release][:author][:id])
        end
        contributors(fact, rname).each { |c| fact.contributors = c }
        Jp.fill_fact_by_hash(fact, info(fact, rname))
        fact.details =
          "A new release #{json[:payload][:release][:name].inspect} has been published " \
          "in #{rname} by #{Fbe.who(fact)}."
        $loog.debug("Release published by #{Fbe.who(fact)}")
      else
        skip(json)
      end
    when 'CreateEvent'
      case json[:payload][:ref_type]
      when 'tag'
        fact.what = 'tag-was-created'
        fact.tag = json[:payload][:ref]
        fact.details = "A new tag #{fact.tag.inspect} has been created in #{rname} by #{Fbe.who(fact)}."
        $loog.debug("Tag #{fact.tag.inspect} created by #{Fbe.who(fact)}")
      else
        skip(json)
      end
    else
      skip(json)
    end
  rescue Octokit::Forbidden
    who =
      begin
        "@#{Fbe.octo.user[:login]}"
      rescue Octokit::Forbidden
        'You'
      end
    raise(RuntimeError, "#{who} doesn't have access to the #{rname} repository, maybe it's private")
  end

  def self.twice?(fb, fact, what, fields)
    pairs = fields.map { [_1, fact[_1]&.first] }
    pairs.reject! { _1.last.nil? }
    eqs =
      pairs.map do |prop, value|
        val =
          case value
          when String then "'#{value}'"
          when Time then value.utc.iso8601
          else value
          end
        "(eq #{prop} #{val})"
      end
    fb.query("(and (eq what '#{what}') #{eqs.join(' ')})").each.to_a.size > 1
  end
  over do |repository, latest|
    rname = Fbe.octo.repo_name_by_id(repository)
    $loog.info("Starting to scan repository #{rname} (##{repository}), the latest event_id was ##{latest}...")
    id = nil
    total = 0
    detected = 0
    first = nil
    rstart = Time.now
    uniques = {
      'issue-was-opened' => %w[where repository issue who],
      'issue-was-closed' => %w[where repository issue who],
      'pull-was-opened' => %w[where repository issue],
      'pull-was-closed' => %w[where repository issue who],
      'pull-was-merged' => %w[where repository issue who],
      'label-was-attached' => %w[where repository issue label],
      'type-was-attached' => %w[where repository issue type]
    }
    Fbe.octo.repository_events(repository).each_with_index do |json, idx|
      Jp.supervision({ 'repo' => rname, 'json' => json.to_h }) do
        if !$options.max_events.nil? && idx >= $options.max_events
          $loog.debug("Already scanned #{idx} events in #{rname}, stop now")
          break
        end
        total += 1
        id = Integer(json[:id])
        first = id if first.nil?
        if id <= latest
          $loog.debug(
            "The event_id ##{id} (no.#{idx}) is not larger than ##{latest}, " \
            "good stop in #{json[:repo][:name]}"
          )
          break
        end
        Fbe.fb.txn do |fbt|
          f =
            Fbe.if_absent(fb: fbt) do |n|
              n.event_id = Integer(json[:id])
              n.where = 'github'
            end
          if f.nil?
            $loog.debug("The event ##{id} just detected is already in the factbase")
            next
          end
          fill(f, json)
          uniques.each { |w, ff| throw :rollback if twice?(fbt, f, w, ff) }
          if f['issue']
            throw :rollback unless Fbe.fb.query(
              "(and
                (eq where '#{f.where}')
                (eq repository #{f.repository})
                (eq issue #{f.issue})
                (exists done))"
            ).each.empty?
            throw :rollback if Fbe::Tombstone.new.has?(f.where, f.repository, f.issue)
          end
          $loog.info("Detected new event_id ##{id} (no.#{idx}) in #{json[:repo][:name]}: #{json[:type]}")
          detected += 1
        end
      end
    end
    $loog.info("In #{rname}, detected #{detected} events out of #{total} scanned in #{rstart.ago}")
    if id.nil?
      $loog.info("No events found in #{rname} in #{rstart.ago}, the latest event_id remains ##{latest}")
      latest
    elsif id <= latest || latest.zero?
      $loog.info("Finished scanning #{rname} correctly in #{rstart.ago}, next time will scan until ##{first}")
      first
    else
      $loog.info("Finished scanning #{rname} correctly in #{rstart.ago}, next time will scan until ##{id}")
      id
    end
  end
end

Fbe.octo.print_trace!
