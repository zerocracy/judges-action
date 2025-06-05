# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

# Judge that monitors facts with exists repository and issue properties and
# create missing [issue/pull]-was-opened fact

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
    (unique issue)
    (empty
      (and
        (eq where 'github')
        (eq repository $repository)
        (eq issue $issue)
        (eq what 'issue-was-opened')))
    (empty
      (and
        (eq where 'github')
        (eq repository $repository)
        (eq issue $issue)
        (eq what 'pull-was-opened'))))"

  consider do |f|
    type =
      if f.what.include?('issue')
        'issue'
      elsif f.what.include?('pull')
        'pull'
      end
    next if type.nil?
    repo = Fbe.octo.repo_name_by_id(f.repository)
    begin
      json = Fbe.octo.issue(repo, f.issue)
    rescue Octokit::NotFound
      $loog.info("The #{type} ##{f.issue} doesn't exist in #{repo}")
      next
    end
    Fbe.fb.txn do |fbt|
      fbt.insert.then do |fact|
        fact.where = 'github'
        fact.what = "#{type}-was-opened"
        fact.repository = f.repository
        fact.issue = f.issue
        fact.when = json[:created_at]
        fact.who = json.dig(:user, :id)
        fact.details = "The #{type} #{Fbe.issue(fact)} has been opened by #{Fbe.who(fact)}."
      end
    end
  end
end

Fbe.octo.print_trace!
