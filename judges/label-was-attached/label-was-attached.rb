# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
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

badges = %w[bug enhancement question]

Fbe.iterate do
  as 'labels-were-scanned'
  by "(agg
    (and
      (eq what 'issue-was-opened')
      (gt issue $before)
      (eq repository $repository)
      (not (exists stale))
      (empty
        (and
          (eq where 'github')
          (eq repository $repository)
          (eq issue $issue)
          (eq what '#{$judge}')))
      (eq where 'github'))
    (min issue))"
  quota_aware
  repeats 64
  over(timeout: ($options.timeout || 60) * 0.8) do |repository, issue|
    begin
      repo = Fbe.octo.repo_name_by_id(repository)
      Fbe.octo.issue_timeline(repo, issue).each do |te|
        next unless te[:event] == 'labeled'
        badge = te[:label][:name]
        next unless badges.include?(badge)
        nn =
          Fbe.if_absent do |n|
            n.where = 'github'
            n.repository = repository
            n.issue = issue
            n.label = te[:label][:name]
            n.what = $judge
          end
        raise "Label already attached to #{repo}##{issue}" if nn.nil?
        nn.who = te[:actor][:id]
        nn.when = te[:created_at]
        nn.details =
          "The '#{nn.label}' label was attached by @#{te[:actor][:login]} " \
          "to the issue #{Fbe.issue(nn)}."
        $loog.info("Label attached to #{Fbe.issue(nn)} found: #{nn.label.inspect}")
      end
    rescue Octokit::NotFound
      $loog.info("Can't find issue ##{issue} in repository ##{repository}")
    end
    issue
  end
end

Fbe.octo.print_trace!
