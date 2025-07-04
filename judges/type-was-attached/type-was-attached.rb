# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

# Judge that monitors issues for type label attachments.
# Scans GitHub issue timelines for 'issue_type_added' and 'issue_type_changed' events,
# records type attachment information into the factbase with details about
# who attached the type and when it happened.
#
# @note Limited to running for 5 minutes maximum to prevent excessive API usage
# @see https://github.com/yegor256/fbe/blob/master/lib/fbe/iterate.rb Implementation of Fbe.iterate

require 'fbe/octo'
require 'fbe/iterate'
require 'fbe/if_absent'
require 'fbe/issue'

events = %w[issue_type_added issue_type_changed]

Fbe.iterate do
  as 'types-were-scanned'
  by "(agg
    (and
      (eq where 'github')
      (eq repository $repository)
      (eq what 'issue-was-opened')
      (gt issue $before)
      (empty
        (and
          (eq where 'github')
          (eq repository $repository)
          (eq issue $issue)
          (eq what 'type-was-attached'))))
    (min issue))"
  quota_aware
  repeats 100
  over(timeout: 5 * 60) do |repository, issue|
    begin
      Fbe.octo.issue_timeline(repository, issue).each do |te|
        next unless events.include?(te[:event])
        tee = Fbe.github_graph.issue_type_event(te[:node_id])
        next if tee.nil?
        nn =
          Fbe.if_absent do |n|
            n.where = 'github'
            n.repository = repository
            n.issue = issue
            n.type = tee.dig('issue_type', 'name')
            n.what = $judge
          end
        next if nn.nil?
        nn.who = tee.dig('actor', 'id')
        nn.when = tee['created_at']
        nn.details =
          "The '#{nn.type}' type was attached by @#{tee.dig('actor', 'login')} " \
          "to the issue #{Fbe.issue(nn)}."
      end
    rescue Octokit::NotFound
      $loog.info("Can't find issue ##{issue} in repository ##{repository}")
    end
    issue
  end
end

Fbe.octo.print_trace!
