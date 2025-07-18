# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

# Judge that monitors facts with exists repository and issue properties and
# create missing [issue/pull]-was-opened fact

require 'octokit'
require 'fbe/conclude'
require 'fbe/issue'
require 'fbe/octo'
require 'fbe/who'

Fbe.conclude do
  quota_aware
  on "(and
    (or (eq what 'pull-was-merged') (eq what 'pull-was-closed'))
    (eq where 'github')
    (exists issue)
    (exists repository)
    (not (exists stale))
    (not (exists hoc)))"
  consider do |f|
    repo = Fbe.octo.repo_name_by_id(f.repository)
    begin
      json = Fbe.octo.pull_request(repo, f.issue)
    rescue Octokit::NotFound
      $loog.info("#{Fbe.issue(f)} doesn't exist in #{repo}")
      f.stale = "pull ##{f.issue}"
      $loog.info("#{Fbe.issue(f)} is lost")
      next
    end
    f.hoc = json[:additions] + json[:deletions]
    $loog.info("Hoc found for #{Fbe.issue(f)}: #{f.hoc}")
  end
end

Fbe.octo.print_trace!
