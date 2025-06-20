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
    (eq what 'pull-was-opened')
    (eq where 'github')
    (exists issue)
    (exists repository)
    (not (exists stale))
    (not (exists branch)))"
  consider do |f|
    repo = Fbe.octo.repo_name_by_id(f.repository)
    begin
      json = Fbe.octo.issue(repo, f.issue)
    rescue Octokit::NotFound
      $loog.info("#{Fbe.issue(f)} doesn't exist in #{repo}")
      f.stale = "pull ##{f.issue}"
      $loog.info("#{Fbe.issue(f)} is lost")
      next
    end
    ref = json.dig(:pull_request, :head, :ref)
    if ref.nil?
      f.stale = "branch ##{f.issue}"
      $loog.info("Branch is lost in #{Fbe.issue(f)}")
    else
      f.branch = ref
      $loog.info("Branch is found in #{Fbe.issue(f)}: #{ref}")
    end
  end
end

Fbe.octo.print_trace!
