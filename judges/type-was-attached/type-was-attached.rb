# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/iterate'
require 'fbe/if_absent'
require 'fbe/issue'

start = Time.now

events = %w[issue_type_added issue_type_changed]

Fbe.iterate do
  as 'types-were-scanned'
  by "(agg (and (eq repository $repository) (eq what 'issue-was-opened') (gt issue $before)) (min issue))"
  quota_aware
  repeats 20
  over do |repository, issue|
    begin
      Fbe.octo.issue_timeline(repository, issue).each do |te|
        if Time.now - start > 5 * 60
          $loog.debug("We are scanning labels for #{start.ago} already, it's time to quit")
          break
        end
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
          "The '##{nn.type}' type was attached by @#{tee.dig('actor', 'login')} " \
          "to the issue #{Fbe.issue(nn)}."
      end
    rescue Octokit::NotFound
      bad = Fbe.fb.query("(and (eq where 'github') (eq repository #{repository}) (eq issue #{issue}))").delete!
      $loog.debug("Can't find issue ##{issue} in repository ##{repository}, deleted #{bad} fact(s) related to it")
    end
    issue
  end
end
