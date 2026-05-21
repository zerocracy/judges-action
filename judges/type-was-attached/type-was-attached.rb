# frozen_string_literal: true

require 'fbe/if_absent'
require 'fbe/issue'
require 'fbe/iterate'
# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'joined'
require_relative '../../lib/issue_was_lost'

events = %w[issue_type_added issue_type_changed]

Fbe.iterate do
  as 'types_were_scanned'
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
          (eq repository $repository)
          (eq issue $issue)
          (eq what '#{$judge}')
          (eq where $where)))
      (eq where 'github'))"
  repeats 64
  over do |repository, issue|
    repo = Fbe.octo.repo_name_by_id(repository)
    timeline =
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
    timeline.each do |te|
      unless events.include?(te[:event])
        $loog.debug("No #{events.joined} events at #{repo}##{issue}")
        next
      end
      tee = Fbe.github_graph.issue_type_event(te[:node_id])
      if tee.nil?
        $loog.debug("Can't fetch event by node ID #{te[:node_id]}")
        next
      end
      Fbe.fb.txn do |fbt|
        nn =
          Fbe.if_absent(fb: fbt) do |n|
            n.issue = issue
            n.what = $judge
            n.type = tee.dig('issue_type', 'name')
            n.repository = repository
            n.where = 'github'
          end
        raise(RuntimeError, "Type already attached to #{repo}##{issue}") if nn.nil?
        nn.who = tee.dig('actor', 'id')
        nn.when = tee['created_at']
        nn.details =
          "The #{nn.type.inspect} type was attached by @#{tee.dig('actor', 'login')} " \
          "to the issue #{Fbe.issue(nn)}."
        $loog.info("Type attached to #{Fbe.issue(nn)} found: #{nn.type.inspect}")
      end
    end
    issue
  end
end

Fbe.octo.print_trace!
