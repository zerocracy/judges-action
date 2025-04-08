# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/conclude'

Fbe.conclude do
  quota_aware
  on '(and (eq what "pull-was-reviewed") (not (exists review_comments)))'
  consider do |f|
    begin
      pl = Fbe.octo.pull_request(Fbe.octo.repo_name_by_id(f.repository), f.issue)
      comments = pl[:review_comments]
    rescue Octokit::NotFound
      comments = 0
    end
    f.review_comments = comments
    $loog.info("Set #{comments} review comments for PR ##{f.issue} in repository #{f.repository}")
  end
end
