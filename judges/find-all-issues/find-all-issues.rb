# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

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
