# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

# Judge that monitors and records milestone events from GitHub repositories.
# Fetches milestones from GitHub repositories and records when they are created
# or modified with their deadlines and assignees.

require 'tago'
require 'fbe/octo'
require 'fbe/iterate'
require 'fbe/if_absent'
require 'fbe/who'
require_relative '../../lib/fill_fact'

Fbe.iterate do
  as 'milestones_were_scanned'
  by '(plus 0 $before)'

  def self.skip_milestone(json, rname = nil)
    repo = rname || json.dig(:repository, :full_name) || 'unknown'
    $loog.debug(
      "Milestone ##{json[:number]} (#{json[:title]}) in #{repo} ignored"
    )
    raise Factbase::Rollback
  end

  def self.fill_up_milestone(fact, json, repo_id, rname)
    fact.when = Time.parse(json[:created_at].iso8601)
    fact.milestone = json[:number]
    fact.repository = repo_id
    fact.who = json[:creator][:id].to_i if json[:creator]
    case json[:state]
    when 'open'
      fact.what = 'milestone-was-set'
      fact.deadline = json[:due_on] ? Time.parse(json[:due_on].iso8601) : nil
      fact.title = json[:title]
      fact.description = json[:description]
      fact.details =
        "A new milestone ##{json[:number]} '#{json[:title]}' has been set " \
          "in #{rname} by #{Fbe.who(fact)} " \
          "#{fact.deadline ? "with deadline #{fact.deadline}" : 'without a deadline'}."
      $loog.debug("New milestone ##{json[:number]} set by #{Fbe.who(fact)}")
    when 'closed'
      fact.what = 'milestone-was-closed'
      fact.title = json[:title]
      fact.description = json[:description]
      fact.closed_at = Time.parse(json[:closed_at].iso8601) if json[:closed_at]
      fact.details =
        "The milestone ##{json[:number]} '#{json[:title]}' has been closed " \
          "in #{rname} by #{Fbe.who(fact)}."
      $loog.debug("Milestone ##{json[:number]} closed by #{Fbe.who(fact)}")
    else
      skip_milestone(json, rname)
    end
  end

  def self.milestone_seen_already?(fact)
    Fbe.fb.query(
      "(and
        (eq repository #{fact.repository})
        (eq milestone #{fact.milestone})
        (eq what '#{fact.what}')
        (eq milestone_event_id '#{fact.milestone_event_id}')
        (eq where 'github'))"
    ).each.any?
  end

  over do |repository, latest|
    rname = repository.to_s.include?('/') ? repository : Fbe.octo.repo_name_by_id(repository)
    $loog.debug("Starting to scan milestones in repository #{rname} (##{repository}), the latest scan was at #{latest}...")
    id = nil
    total = 0
    detected = 0
    rstart = Time.now
    milestones = Fbe.octo.milestones(rname, state: 'all')
    milestones.each do |milestone|
      total += 1
      updated_time = Time.parse(milestone[:updated_at].iso8601).to_i
      id = updated_time
      id = [id, updated_time].compact.max
      if updated_time <= latest
        $loog.debug("Milestone ##{milestone[:number]} (updated #{updated_time}) is not newer than #{latest}, skipping")
        next
      end
      Fbe.fb.txn do |fbt|
        f =
          Fbe.if_absent(fb: fbt) do |n|
            n.where = 'github'
            n.milestone_event_id = "#{repository}-#{milestone[:number]}-#{updated_time}"
          end
        if f.nil?
          $loog.debug("The milestone event ##{milestone[:number]}@#{updated_time} is already in the factbase")
        else
          fill_up_milestone(f, milestone, repository, rname)
          if milestone_seen_already?(f)
            $loog.debug("Milestone ##{milestone[:number]} #{f.what} already recorded, skipping")
            skip_milestone(milestone, rname)
          end
          $loog.info("Detected new milestone event ##{milestone[:number]} (updated #{updated_time}) in #{rname}: #{milestone[:title]}")
          detected += 1
        end
      end
    end
    $loog.info("In #{rname}, detected #{detected} milestone events out of #{total} scanned in #{rstart.ago}")
    if id.nil?
      $loog.debug("No new milestones found in #{rname} in #{rstart.ago}, the latest timestamp remains ##{latest}")
      latest
    else
      $loog.debug("Finished scanning milestones in #{rname} in #{rstart.ago}, next time will scan until ##{id}")
      id
    end
  end
end
