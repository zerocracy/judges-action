# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
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
require 'fbe/tombstone'
require 'fbe/who'
require 'joined'
require 'logger'
require 'time'
require_relative '../../lib/issue_was_lost'

%w[issue pull].each do |type|
  Fbe.iterate do
    as "min_#{type}_was_found"
    sort_by 'issue'
    by "
      (and
        (eq what '#{type}-was-opened')
        (eq repository $repository)
        (gt issue $before)
        (eq where 'github'))"
    over do |repository, issue|
      repo = Fbe.octo.repo_name_by_id(repository)
      after =
        begin
          Fbe.octo.issue(repo, issue)[:created_at]
        rescue Octokit::NotFound, Octokit::Deprecated => e
          $loog.info("The #{type} ##{issue} doesn't exist, time to start from zero: #{e.message}")
          Jp.issue_was_lost('github', repository, issue)
          next 0
        end
      if after.nil?
        $loog.info("The #{type} ##{issue} in #{repo} return empty created_at field")
        next 0
      end
      seen = []
      found = []
      first = issue
      elapsed($loog, level: Logger::INFO) do
        Fbe.octo.search_issues("repo:#{repo} type:#{type} created:>=#{after.iso8601[0..9]}")[:items].each do |json|
          next if Fbe.octo.off_quota?
          i = json[:number]
          seen << i
          next if Fbe::Tombstone.new.has?('github', repository, i)
          Fbe.fb.txn do |fbt|
            f =
              Fbe.if_absent(fb: fbt) do |ff|
                ff.issue = i
                ff.repository = repository
                ff.what = "#{type}-was-opened"
                ff.where = 'github'
                issue = ff.issue
              end
            next if f.nil?
            found << f.issue
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
            f.details = "The #{type} #{Fbe.issue(f)} has been earlier opened by #{Fbe.who(f)}."
            $loog.info("The #{Fbe.issue(f)} was opened by #{Fbe.who(f)} #{f.when.ago} ago")
          end
        end
        issue = first if issue < first
        m = [
          "Checked #{seen.count} #{type}s in #{repo}",
          ("(#{seen.joined(max: 8)})" unless seen.empty?),
          "created >= #{after.iso8601[0..9]};",
          "from ##{first} to ##{issue};",
          'found',
          (found.empty? ? 'nothing' : "#{found.count} (#{found.joined(max: 8)})")
        ].compact.join(' ')
        throw m.to_sym
      end
      issue
    end
  end
end

Fbe.octo.print_trace!
