# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/if_absent'
require 'fbe/iterate'
require 'fbe/octo'
require 'fbe/who'
require 'octokit'
require 'tago'

Fbe.iterate do
  as 'milestones_were_scanned'
  by '(plus 0 $before)'
  over do |repository, before|
    repo = Fbe.octo.repo_name_by_id(repository)
    milestones =
      begin
        Fbe.octo.list_milestones(repo, state: :all, sort: :created, direction: :asc)
      rescue Octokit::NotFound, Octokit::Deprecated => e
        $loog.info("Milestones are not available in #{repo}: #{e.message}")
        next before
      rescue Octokit::Forbidden => e
        $loog.warn("[#{$judge}] Access forbidden to milestones in #{repo}: #{e.class}: #{e.message}")
        next before
      end
    latest = before
    milestones.each do |json|
      number = json[:number]
      next unless number > before
      latest = [latest, number].max
      Fbe.fb.txn do |fbt|
        n =
          Fbe.if_absent(fb: fbt) do |f|
            f.what = $judge
            f.where = 'github'
            f.repository = repository
            f.milestone = number
          end
        next if n.nil?
        n.when = json[:created_at]
        creator = json.dig(:creator, :id)
        if creator
          n.who = creator
        else
          n.stale = 'who'
        end
        n.deadline = json[:due_on] unless json[:due_on].nil?
        n.details = "The milestone ##{n.milestone} in #{repo} was set by #{creator ? Fbe.who(n) : 'an unknown user'}."
        $loog.info("The milestone ##{n.milestone} in #{repo} was set #{n.when.ago} ago")
      end
    end
    latest
  end
end

Fbe.octo.print_trace!
