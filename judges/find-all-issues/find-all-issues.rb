# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'time'
require 'fbe/fb'
require 'fbe/octo'
require 'fbe/iterate'
require 'fbe/if_absent'
require 'fbe/who'
require 'fbe/issue'

Fbe.iterate do
  as 'min-issue-was-found'
  by "(agg (and (eq where 'github') (eq repository $repository) (eq what 'issue-was-opened')) (min issue))"
  quota_aware
  over do |repository, issue|
    repo = Fbe.octo.repo_name_by_id(repository)
    begin
      after = Fbe.octo.issue(repo, issue)[:created_at]
    rescue Octokit::NotFound
      next 0
    end
    total = 0
    before = Time.now
    Fbe.octo.search_issues("repo:#{repo} type:issue created:<=#{after.iso8601[0..9]}")[:items].each do |json|
      total += 1
      f =
        Fbe.if_absent do |ff|
          ff.where = 'github'
          ff.what = 'issue-was-opened'
          ff.repository = repository
          ff.issue = json[:number]
        end
      next if f.nil?
      f.when = json[:created_at]
      f.who = json.dig(:user, :id)
      f.details = "The issue #{Fbe.issue(f)} has been opened by #{Fbe.who(f)}."
    end
    $loog.info("Checked #{total} issues in #{repo} in #{before.ago}")
    issue
  end
end
