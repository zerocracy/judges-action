# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/fb'
require 'fbe/issue'
require 'fbe/iterate'
require 'fbe/octo'
require 'fbe/tombstone'
require 'fbe/who'
require 'octokit'
require 'tago'
require_relative '../../lib/issue_was_lost'

Fbe.iterate do
  as 'latest_issue_was_found'
  by '(plus 0 $before)'
  over do |repository, latest|
    next latest if latest.positive?
    repo = Fbe.octo.repo_name_by_id(repository)
    json =
      begin
        Fbe.octo.with_disable_auto_paginate do |octo|
          octo.list_issues(repo, state: :all, sort: :created, direction: :desc, page: 1, per_page: 1).first
        end
      rescue Octokit::NotFound, Octokit::Deprecated => e
        $loog.info("Issues list not available for #{repo}: #{e.message}")
        next latest
      rescue Octokit::Forbidden => e
        $loog.warn(
          "[#{$judge}] Access forbidden to issues list for #{repo} " \
          "(transient, will retry next cycle): #{e.class}: #{e.message}"
        )
        next latest
      end
    next latest if json.nil?
    i = json[:number]
    next latest if Fbe::Tombstone.new.has?('github', repository, i)
    Fbe.fb.txn do |fbt|
      f =
        Fbe.if_absent(fb: fbt) do |ff|
          ff.issue = i
          ff.what = "#{json[:pull_request].nil? ? 'issue' : 'pull'}-was-opened"
          ff.repository = repository
          ff.where = 'github'
        end
      next if f.nil?
      f.when = json[:created_at]
      f.who = json.dig(:user, :id)
      if json[:pull_request]
        ref =
          begin
            Fbe.octo.pull_request(repo, f.issue).dig(:head, :ref)
          rescue Octokit::NotFound, Octokit::Deprecated => e
            $loog.info("The pull ##{f.issue} doesn't exist in #{repo}: #{e.message}")
            Jp.issue_was_lost(f.where, f.repository, f.issue)
            next i
          rescue Octokit::Forbidden => e
            $loog.warn(
              "[#{$judge}] Access forbidden to pull ##{f.issue} in #{repo} " \
              "(transient, will retry next cycle): #{e.class}: #{e.message}"
            )
            next i
          end
        if ref
          f.branch = ref
        else
          f.stale = 'branch'
        end
      end
      f.details = "The issue #{Fbe.issue(f)} is the first we found, opened by #{Fbe.who(f)}."
      $loog.info("The issue #{Fbe.issue(f)} was opened by #{Fbe.who(f)} #{f.when.ago} ago")
    end
    json[:number]
  end
end

Fbe.octo.print_trace!
