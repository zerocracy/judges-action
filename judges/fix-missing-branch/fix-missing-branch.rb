# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

# Judge that monitors facts with exists repository and issue properties and
# create missing [issue/pull]-was-opened fact

require 'octokit'
require 'fbe/consider'
require 'fbe/issue'
require 'fbe/octo'
require 'fbe/who'
require_relative '../../lib/issue_was_lost'

Fbe.consider(
  "(and
    (eq what 'pull-was-opened')
    (absent branch)
    (absent stale)
    (absent tombstone)
    (absent done)
    (exists issue)
    (exists repository)
    (eq where 'github'))"
) do |f|
  repo = Fbe.octo.repo_name_by_id(f.repository)
  json =
    begin
      Fbe.octo.issue(repo, f.issue)
    rescue Octokit::NotFound, Octokit::Deprecated => e
      $loog.info("#{Fbe.issue(f)} doesn't exist in #{repo}: #{e.message}")
      Jp.issue_was_lost(f.where, f.repository, f.issue)
      next
    end
  ref = json.dig(:pull_request, :head, :ref)
  if ref.nil?
    f.stale = 'branch'
    $loog.info("Branch is lost in #{Fbe.issue(f)}")
  else
    f.branch = ref
    $loog.info("Branch is found in #{Fbe.issue(f)}: #{f.branch}")
  end
end

Fbe.octo.print_trace!
