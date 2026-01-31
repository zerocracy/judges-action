# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

# Judge that monitors ns with exists repository and issue properties and
# create missing pull-was-opened n.

require 'fbe/octo'
require 'fbe/conclude'
require 'fbe/issue'
require 'fbe/who'
require 'octokit'
require 'tago'
require_relative '../../lib/issue_was_lost'

Fbe.conclude do
  on "(and
    (eq where 'github')
    (exists repository)
    (exists issue)
    (absent stale)
    (absent tombstone)
    (absent done)
    (or
      (eq what 'pull-was-closed')
      (eq what 'pull-was-merged')
      (eq what 'pull-was-reviewed')
      (eq what 'code-was-contributed')
      (eq what 'bad-branch-name-was-punished')
      (eq what 'code-contribution-was-rewarded')
      (eq what 'code-review-was-rewarded')
      (eq what 'code-was-reviewed'))
    (unique repository issue)
    (empty
      (and
        (eq where $where)
        (eq repository $repository)
        (eq issue $issue)
        (eq what '#{$judge}'))))"
  follow 'where repository issue'
  draw do |n, f|
    repo = Fbe.octo.repo_name_by_id(f.repository)
    json =
      begin
        Fbe.octo.issue(repo, f.issue)
      rescue Octokit::NotFound, Octokit::Deprecated => e
        $loog.info("The pull ##{f.issue} doesn't exist in #{repo}: #{e.message}")
        Jp.issue_was_lost(f.where, f.repository, f.issue)
        next issue
      end
    n.what = $judge
    n.when = json[:created_at]
    n.who = json.dig(:user, :id)
    ref = Fbe.octo.pull_request(repo, f.issue).dig(:head, :ref)
    if ref
      n.branch = ref
    else
      n.stale = 'branch'
    end
    n.details = "The pull #{Fbe.issue(n)} has been opened earlier by #{Fbe.who(n)}."
    $loog.info("The pull #{Fbe.issue(n)} was opened #{n.when.ago} ago")
  end
end

Fbe.octo.print_trace!
