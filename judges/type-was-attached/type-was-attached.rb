# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
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
require 'joined'

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
    begin
      repo = Fbe.octo.repo_name_by_id(repository)
      Fbe.octo.issue_timeline(repo, issue).each do |te|
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
          raise "Type already attached to #{repo}##{issue}" if nn.nil?
          nn.who = tee.dig('actor', 'id')
          nn.when = tee['created_at']
          nn.details =
            "The #{nn.type.inspect} type was attached by @#{tee.dig('actor', 'login')} " \
            "to the issue #{Fbe.issue(nn)}."
          $loog.info("Type attached to #{Fbe.issue(nn)} found: #{nn.type.inspect}")
        end
      end
    rescue Octokit::NotFound
      $loog.info("Can't find issue ##{issue} in repository ##{repository}")
      Fbe.fb.query(
        "(and (eq issue #{issue}) (eq repository #{repository}) (eq where 'github') (absent stale))"
      ).each { |f| f.stale = 'issue' }
    end
    issue
  end
end

Fbe.octo.print_trace!
