# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/conclude'

Fbe.conclude do
  quota_aware
  on '(and (eq what "pull-was-reviewed") (not (exists review_comments)))'
  consider do |f|
    pl = Fbe.octo.pull_request(Fbe.octo.repo_name_by_id(f.repository), f.issue)
    f.review_comments = pl[:review_comments]
    $loog.info("Set #{pl[:review_comments]} review comments for PR ##{f.issue} in repository #{f.repository}")
  end
end
