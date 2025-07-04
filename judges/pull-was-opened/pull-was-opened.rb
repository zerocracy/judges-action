# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

# Judge that monitors ns with exists repository and issue properties and
# create missing pull-was-opened n.

require 'fbe/octo'
require 'fbe/conclude'
require 'fbe/issue'
require 'fbe/who'

Fbe.conclude do
  quota_aware
  on "(and
    (eq where 'github')
    (exists repository)
    (exists what)
    (exists issue)
    (not (exists stale))
    (or (eq what 'pull-was-closed') (eq what 'pull-was-merged'))
    (unique issue)
    (empty
      (and
        (eq where 'github')
        (eq repository $repository)
        (eq issue $issue)
        (eq what '#{$judge}'))))"
  follow 'where repository issue'
  draw do |n, f|
    repo = Fbe.octo.repo_name_by_id(f.repository)
    begin
      json = Fbe.octo.issue(repo, f.issue)
      n.what = $judge
      n.when = json[:created_at]
      n.who = json.dig(:user, :id)
      ref = Fbe.octo.pull_request(repo, f.issue).dig(:head, :ref)
      if ref
        n.branch = ref
      else
        n.stale = 'branch'
      end
      n.details = "#{Fbe.issue(n)} has been opened by #{Fbe.who(n)}."
      $loog.debug("The opening for #{Fbe.issue(n)} was found")
    rescue Octokit::NotFound
      $loog.info("The pull ##{f.issue} doesn't exist in #{repo}")
      f.stale = "issue #{f.issue}"
      throw :rollback
    end
  end
end

Fbe.octo.print_trace!
