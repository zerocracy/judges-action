# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/conclude'

Fbe.conclude do
  quota_aware
  on '(and
    (or (eq what "pull-was-reviewed") (eq what "pull-was-merged"))
    (not (exists review_comments)))'
  consider do |f|
    begin
      pl = Fbe.octo.pull_request(Fbe.octo.repo_name_by_id(f.repository), f.issue)
    rescue Octokit::NotFound
      next
    end
    f.review_comments = pl[:review_comments]
    $loog.info("Set #{pl[:review_comments]} review comments for PR ##{f.issue} in repository #{f.repository}")
  end
end
