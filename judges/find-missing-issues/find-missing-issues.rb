# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

# Judge that finds and records all issues in GitHub repositories.
# Iterates through repositories, identifies existing issues by searching GitHub,
# and records them in the factbase with metadata about when they were opened
# and by whom. Used to ensure a complete record of issues in the monitored repos.
#
# We have this script because "github-events.rb" is unreliable - it may miss.
# some issues, due to GitHub limitations. GitHub doesn't allow us to scan the
# entire history of all events, only the last 1000. Moreover, there could be
# connectivity problems.
#
# @see https://github.com/yegor256/fbe/blob/master/lib/fbe/iterate.rb Implementation of Fbe.iterate
# @see https://github.com/yegor256/fbe/blob/master/lib/fbe/if_absent.rb Implementation of Fbe.if_absent

require 'time'
require 'fbe/consider'
require 'fbe/fb'
require 'fbe/octo'
require 'fbe/if_absent'
require 'fbe/who'
require 'fbe/issue'
require_relative '../../lib/issue_was_lost'

Fbe.consider('(and (eq where "github") (exists repository) (unique repository))') do |r|
  repo = Fbe.octo.repo_name_by_id(r.repository)
  issues = Fbe.fb.query(
    "(and (eq repository #{r.repository}) (exists issue) (eq where 'github') (unique issue))"
  ).each.map(&:issue).uniq.sort
  next if issues.empty?
  must = (issues.min..issues.max).to_a
  missing = must - issues
  added = 0
  checked = 0
  missing.take(200).each do |i|
    json =
      begin
        Fbe.octo.issue(repo, i)
      rescue Octokit::NotFound, Octokit::Deprecated => e
        $loog.info("The issue #{repo}##{i} doesn't exist: #{e.message}")
        Jp.issue_was_lost('github', r.repository, i)
        next
      end
    checked += 1
    if json[:number].nil?
      $loog.warn("Apparently, the JSON for the issue ##{i} doesn't have 'number' field")
      Jp.issue_was_lost('github', r.repository, i)
      next
    end
    type = json[:pull_request] ? 'pull' : 'issue'
    Fbe.fb.txn do |fbt|
      f =
        Fbe.if_absent(fb: fbt) do |n|
          n.issue = json[:number]
          n.what = "#{type}-was-opened"
          n.repository = r.repository
          n.where = 'github'
        end
      next if f.nil?
      f.when = json[:created_at]
      f.who = json.dig(:user, :id)
      if type == 'pull'
        ref = Fbe.octo.pull_request(repo, f.issue).dig(:head, :ref)
        if ref
          f.branch = ref
        else
          f.stale = 'branch'
        end
      end
      f.details = "The missing #{type} #{Fbe.issue(f)} has been opened by #{Fbe.who(f)}."
      $loog.info("Lost #{type} #{Fbe.issue(f)} was found")
    end
    added += 1
  end
  if missing.empty?
    $loog.info("No missing issues in #{repo}")
  else
    $loog.info("Checked #{checked} out of #{missing.count} missing issues in #{repo}, #{added} facts added")
  end
end

Fbe.octo.print_trace!
