# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/consider'
require 'fbe/issue'
require 'fbe/octo'
require 'fbe/who'
require 'octokit'
require_relative '../../lib/fill_fact'
require_relative '../../lib/issue_was_lost'
require_relative '../../lib/pull_request'

Fbe.consider(
  "(and
    (or (eq what 'pull-was-merged') (eq what 'pull-was-closed'))
    (eq where 'github')
    (exists issue)
    (exists repository)
    (absent stale)
    (absent tombstone)
    (absent done)
    (absent comments))"
) do |f|
  repo = Fbe.octo.repo_name_by_id(f.repository)
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
  Jp.fill_fact_by_hash(f, Jp.comments_info(json, repo:))
  $loog.info("Comments found for #{Fbe.issue(f)}: #{f.comments}")
end

Fbe.octo.print_trace!
