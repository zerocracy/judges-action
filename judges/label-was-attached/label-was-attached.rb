# frozen_string_literal: true

# MIT License
#
# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/iterate'
require 'fbe/if_absent'
require 'fbe/issue'

start = Time.now

Fbe.iterate do
  as 'labels-were-scanned'
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
        next unless te[:event] == 'labeled'
        badge = te[:label][:name]
        next unless %w[bug enhancement question].include?(badge)
        nn =
          Fbe.if_absent do |n|
            n.where = 'github'
            n.repository = repository
            n.issue = issue
            n.label = te[:label][:name]
            n.what = $judge
          end
        next if nn.nil?
        nn.who = te[:actor][:id]
        nn.when = te[:created_at]
        nn.details =
          "The '##{nn.label}' label was attached by @#{te[:actor][:login]} " \
          "to the issue #{Fbe.issue(nn)}."
      end
    rescue Octokit::NotFound
      Fbe.fb.query("(and (eq where 'github') (eq repository #{repository}) (eq issue #{issue}))").delete!
    end
    issue
  end
end
