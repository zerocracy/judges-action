# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

# Judge that monitors issues for label attachments.
# Scans GitHub issue timelines for 'labeled' events, specifically looking for
# standard badges (bug, enhancement, question), records label attachment information
# into the factbase with details about who attached the label and when it happened.
#
# @note Limited to running for 5 minutes maximum to prevent excessive API usage
# @see https://github.com/yegor256/fbe/blob/master/lib/fbe/iterate.rb Implementation of Fbe.iterate
# @see https://github.com/yegor256/fbe/blob/master/lib/fbe/if_absent.rb Implementation of Fbe.if_absent

require 'fbe/octo'
require 'fbe/iterate'
require 'fbe/if_absent'
require 'fbe/issue'
require_relative '../../lib/issue_was_lost'

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
    repo = Fbe.octo.repo_name_by_id(repository)
    events =
      begin
        Fbe.octo.issue_timeline(repo, issue)
      rescue Octokit::NotFound, Octokit::Deprecated => e
        $loog.info("Can't find issue ##{issue} in repository ##{repository}: #{e.message}")
        Jp.issue_was_lost('github', repository, issue)
        next
      end
    events.each do |te|
      next unless te[:event] == 'labeled'
      badge = te[:label][:name]
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
        nn.who = te[:actor][:id]
        nn.when = te[:created_at]
        nn.details =
          "The #{nn.label.inspect} label was attached by @#{te[:actor][:login]} " \
          "to the issue #{Fbe.issue(nn)}."
        $loog.info("Label attached to #{Fbe.issue(nn)} found: #{nn.label.inspect}")
      end
    end
    issue
  end
end

Fbe.octo.print_trace!
