# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/fb'
require 'fbe/iterate'
require 'fbe/issue'
require 'fbe/octo'
require 'fbe/who'

Fbe.iterate do
  as 'earliest_issue_was_found'
  by '(plus 0 $before)'
  over do |repository, latest|
    next latest if latest.positive?
    repo = Fbe.octo.repo_name_by_id(repository)
    json =
      Fbe.octo.with_disable_auto_paginate do |octo|
        octo.list_issues(repo, state: :all, sort: :created, direction: :asc, page: 1, per_page: 1).first
      end
    next latest if json.nil?
    Fbe.fb.txn do |fbt|
      f =
        Fbe.if_absent(fb: fbt) do |ff|
          ff.issue = json[:number]
          ff.what = "#{json[:pull_request].nil? ? 'issue' : 'pull'}-was-opened"
          ff.repository = repository
          ff.where = 'github'
        end
      next if f.nil?
      f.when = json[:created_at]
      f.who = json.dig(:user, :id)
      if json[:pull_request]
        ref = Fbe.octo.pull_request(repo, f.issue).dig(:head, :ref)
        if ref
          f.branch = ref
        else
          f.stale = 'branch'
        end
      end
      f.details = "The issue #{Fbe.issue(f)} is the earliest we found, opened by #{Fbe.who(f)}."
      $loog.info("The opening of #{Fbe.issue(f)} by #{Fbe.who(f)} was found")
    end
    json[:number]
  end
end

Fbe.octo.print_trace!
