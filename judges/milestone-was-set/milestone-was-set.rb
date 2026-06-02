# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/fb'
require 'fbe/if_absent'
require 'fbe/octo'
require 'fbe/unmask_repos'
require 'octokit'

Fbe.unmask_repos do |repo|
  milestones =
    begin
      Fbe.octo.list_milestones(repo, state: 'all')
    rescue NoMethodError => e
      raise unless e.name == :list_milestones
      $loog.debug("list_milestones() not available (likely FakeOctokit), skipping #{repo}")
      next
    rescue Octokit::NotFound, Octokit::Deprecated => e
      $loog.info("Milestones not available for #{repo}: #{e.message}")
      next
    rescue Octokit::Forbidden => e
      $loog.warn("[#{$judge}] Access forbidden to milestones for #{repo}: #{e.class}: #{e.message}")
      next
    end
  milestones.each do |m|
    Fbe.fb.txn do |fbt|
      f =
        Fbe.if_absent(fb: fbt) do |ff|
          ff.what = $judge
          ff.milestone = m[:number]
          ff.repository = Fbe.octo.repo_id_by_name(repo)
          ff.where = 'github'
        end
      next if f.nil?
      f.when = m[:created_at]
      due = m[:due_on]
      f.deadline = due if due
      f.who = m.dig(:creator, :id)
      f.details = "Milestone #{m[:title].inspect} ##{m[:number]} was set in #{repo}."
      $loog.info("Milestone ##{m[:number]} found in #{repo}: #{m[:title].inspect}")
    end
  end
end

Fbe.octo.print_trace!
