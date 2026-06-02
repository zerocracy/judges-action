# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/if_absent'
require 'fbe/issue'
require 'fbe/iterate'
require 'fbe/octo'
require_relative '../../lib/issue_was_lost'
require_relative '../../lib/repo_name_of'

badges = %w[bug enhancement question]

Fbe.iterate do
  as 'labels_were_scanned'
  sort_by 'issue'
  by "
    (and
      (eq what 'issue-was-opened')
      (gt issue $before)
      (eq repository $repository)
      (absent stale)
      (absent tombstone)
      (absent done)
      (empty
        (and
          (eq where $where)
          (eq repository $repository)
          (eq issue $issue)
          (eq what '#{$judge}')))
      (eq where 'github'))"
  repeats 64
  over do |repository, issue|
    repo, status = Jp.repo_name_of(repository)
    if repo.nil?
      Jp.issue_was_lost('github', repository, issue) if status == :lost
      next issue
    end
    events =
      begin
        Fbe.octo.issue_timeline(repo, issue)
      rescue Octokit::NotFound, Octokit::Deprecated => e
        $loog.info("Can't find issue ##{issue} in repository ##{repository}: #{e.message}")
        Jp.issue_was_lost('github', repository, issue)
        next issue
      rescue Octokit::Forbidden => e
        $loog.warn(
          "[#{$judge}] Access forbidden to issue ##{issue} in repository ##{repository} " \
          "(transient, will retry next cycle): #{e.class}: #{e.message}"
        )
        next issue
      end
    events.each do |te|
      next unless te[:event] == 'labeled'
      badge = te.dig(:label, :name)
      next unless badges.include?(badge)
      Fbe.fb.txn do |fbt|
        nn =
          Fbe.if_absent(fb: fbt) do |n|
            n.issue = issue
            n.label = badge
            n.what = $judge
            n.repository = repository
            n.where = 'github'
          end
        if nn.nil?
          $loog.warn("A label #{badge.inspect} is already attached to #{repo}##{issue}")
          next
        end
        who = te.dig(:actor, :id)
        if who
          nn.who = who
        else
          nn.stale = 'who'
        end
        nn.when = te[:created_at]
        actor = te.dig(:actor, :login)
        nn.details =
          "The #{nn.label.inspect} label was attached by #{actor ? "@#{actor}" : 'an unknown actor'} " \
          "to the issue #{Fbe.issue(nn)}."
        $loog.info("Label attached to #{Fbe.issue(nn)} found: #{nn.label.inspect}")
      end
    end
    issue
  end
end

Fbe.octo.print_trace!
