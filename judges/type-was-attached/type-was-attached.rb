# frozen_string_literal: true

require 'fbe/github_graph'
require 'fbe/if_absent'
require 'fbe/issue'
require 'fbe/iterate'
# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'joined'

events = %w[IssueTypeAddedEvent IssueTypeChangedEvent]

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
      Fbe.octo.issue(repo, issue)
      owner, name = repo.split('/')
      Fbe.github_graph.issue_timeline_items(owner, name, issue).each do |te|
        unless events.include?(te['__typename'])
          $loog.debug("No #{events.joined} events at #{repo}##{issue}")
          next
        end
        tee = Fbe.github_graph.issue_type_event(te['id'])
        if tee.nil?
          $loog.debug("Can't fetch event by node ID #{te['id']}")
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
