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

{
  'issue-was-opened' => :user,
  'pull-was-opened' => :user,
  'issue-was-closed' => :closed_by,
  'pull-was-closed' => :closed_by,
  'pull-was-merged' => :merged_by
}.each do |w, a|
  Fbe.consider(
    "(and
      (absent who)
      (eq what '#{w}')
      (exists issue)
      (exists repository)
      (absent stale)
      (absent tombstone)
      (absent done)
      (eq where 'github'))"
  ) do |f|
    repo = Fbe.octo.repo_name_by_id(f.repository)
    json =
      begin
        Fbe.octo.issue(repo, f.issue)
      rescue Octokit::NotFound
        $loog.info("#{Fbe.issue(f)} doesn't exist in #{repo}")
        f.stale = 'issue'
        $loog.info("#{Fbe.issue(f)} is lost")
        next
      end
    who = json.dig(a, :id)
    if who.nil?
      f.stale = 'who'
      $loog.info("Authorship is lost in #{Fbe.issue(f)}")
    else
      f.who = who
      $loog.info("Authorship is restored in #{Fbe.issue(f)}: #{f.who}")
    end
  end
end

Fbe.octo.print_trace!
