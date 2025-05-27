# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

# Judge that finds and records all issues in GitHub repositories.
# Iterates through repositories, identifies existing issues by searching GitHub,
# and records them in the factbase with metadata about when they were opened
# and by whom. Used to ensure a complete record of issues in the monitored repos.
#
# We have this script because "github-events.rb" is unreliable - it may miss.
# some issues, due to GitHub limitations. GitHub doesn't allow us to scan the
# entire history of all events, only the last 1000. Moreover, there could be
# connectivity problems.
#
# @see https://github.com/yegor256/fbe/blob/master/lib/fbe/iterate.rb Implementation of Fbe.iterate
# @see https://github.com/yegor256/fbe/blob/master/lib/fbe/if_absent.rb Implementation of Fbe.if_absent

require 'time'
require 'fbe/fb'
require 'fbe/octo'
require 'fbe/iterate'
require 'fbe/if_absent'
require 'fbe/who'
require 'fbe/issue'

%w[issue pull].each do |type|
  Fbe.iterate do
    as "min-#{type}-was-found"
    by "
      (agg
        (and
          (eq where 'github')
          (eq repository $repository)
          (eq what '#{type}-was-opened')
          (gt issue $before))
        (min issue))"
    quota_aware
    over do |repository, issue|
      repo = Fbe.octo.repo_name_by_id(repository)
      begin
        after = Fbe.octo.issue(repo, issue)[:created_at]
      rescue Octokit::NotFound
        $loog.debug("The #{type} ##{issue} doesn't exist, time to start from zero")
        next 0
      end
      total = 0
      before = Time.now
      Fbe.octo.search_issues("repo:#{repo} type:#{type} created:>=#{after.iso8601[0..9]}")[:items].each do |json|
        total += 1
        f =
          Fbe.if_absent do |ff|
            ff.where = 'github'
            ff.what = "#{type}-was-opened"
            ff.repository = repository
            ff.issue = json[:number]
            issue = ff.issue
          end
        next if f.nil?
        f.when = json[:created_at]
        f.who = json.dig(:user, :id)
        f.details = "The #{type} #{Fbe.issue(f)} has been opened by #{Fbe.who(f)}."
      end
      $loog.info("Checked #{total} #{type}s in #{repo} in #{before.ago}")
      issue
    end
  end
end
