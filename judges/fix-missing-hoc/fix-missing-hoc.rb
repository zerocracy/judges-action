# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/consider'
require 'fbe/issue'
require 'fbe/octo'
require 'fbe/who'
require 'octokit'
require_relative '../../lib/issue_was_lost'
require_relative '../../lib/repo_name_of'

Fbe.consider(
  "(and
    (or (eq what 'pull-was-merged') (eq what 'pull-was-closed'))
    (eq where 'github')
    (exists issue)
    (exists repository)
    (absent stale)
    (absent tombstone)
    (absent done)
    (absent hoc))"
) do |f|
  repo, status = Jp.repo_name_of(f.repository)
  if repo.nil?
    Jp.issue_was_lost(f.where, f.repository, f.issue) if status == :lost
    next
  end
  json =
    begin
      Fbe.octo.pull_request(repo, f.issue)
    rescue Octokit::NotFound, Octokit::Deprecated => e
      $loog.info("#{Fbe.issue(f)} doesn't exist in #{repo}: #{e.message}")
      Jp.issue_was_lost(f.where, f.repository, f.issue)
      next
    rescue Octokit::Forbidden => e
      $loog.warn(
        "[#{$judge}] Access forbidden to #{Fbe.issue(f)} in #{repo} " \
        "(transient, will retry next cycle): #{e.class}: #{e.message}"
      )
      next
    end
  f.hoc = json[:additions] + json[:deletions]
  $loog.info("Hoc found for #{Fbe.issue(f)}: #{f.hoc}")
end

Fbe.octo.print_trace!
