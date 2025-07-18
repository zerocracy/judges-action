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

require 'elapsed'
require 'fbe/fb'
require 'fbe/if_absent'
require 'fbe/issue'
require 'fbe/iterate'
require 'fbe/octo'
require 'fbe/who'
require 'time'

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
        $loog.info("The #{type} ##{issue} doesn't exist, time to start from zero")
        next 0
      end
      total = 0
      found = 0
      first = issue
      elapsed($loog) do
        Fbe.octo.search_issues("repo:#{repo} type:#{type} created:>=#{after.iso8601[0..9]}")[:items].each do |json|
          next if Fbe.octo.off_quota?
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
          found += 1
          f.when = json[:created_at]
          f.who = json.dig(:user, :id)
          if type == 'pull'
            ref = Fbe.octo.pull_request(repo, f.issue).dig(:head, :ref)
            if ref
              f.branch = ref
            else
              f.stale = 'branch'
            end
          end
          f.details = "The #{type} #{Fbe.issue(f)} has been opened by #{Fbe.who(f)}."
        end
        throw :"Checked #{total} #{type}s in #{repo}, from #{first} to #{issue}, found #{found}"
      end
      issue
    end
  end
end

Fbe.octo.print_trace!
