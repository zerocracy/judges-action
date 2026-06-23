# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/consider'
require 'fbe/if_absent'
require 'fbe/octo'
require 'octokit'

Fbe.consider(
  '(and
    (exists repository)
    (eq where \'github\')
    (unique repository)
    (absent stale)
    (absent tombstone))'
) do |f|
  repo = Fbe.octo.repo_name_by_id(f.repository)
  milestones =
    begin
      Fbe.octo.list_milestones(repo, state: 'all')
    rescue Octokit::NotFound, Octokit::Deprecated => e
      $loog.info("Can't list milestones for #{repo}: #{e.message}")
      next
    rescue Octokit::Forbidden => e
      $loog.warn(
        "[#{$judge}] Access forbidden to milestones in #{repo} " \
        "(transient, will retry next cycle): #{e.class}: #{e.message}"
      )
      next
    end
  milestones.each do |m|
    Fbe.fb.txn do |fbt|
      nn =
        Fbe.if_absent(fb: fbt) do |nnn|
          nnn.what = $judge
          nnn.where = 'github'
          nnn.repository = f.repository
          nnn.milestone = m[:number]
        end
      if nn.nil?
        $loog.warn("Milestone ##{m[:number]} is already in the factbase for #{repo}")
        next
      end
      nn.when = m[:created_at]
      nn.deadline = m[:due_on] if m[:due_on]
      nn.who = m.dig(:creator, :id)
      nn.details = "The milestone ##{m[:number]} \"#{m[:title]}\" was set."
      $loog.info("Milestone ##{m[:number]} \"#{m[:title]}\" found in #{repo}")
    end
  end
end

Fbe.octo.print_trace!
