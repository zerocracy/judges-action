# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/github_graph'
require 'fbe/octo'
require 'fbe/unmask_repos'

def total_issues_created(fact)
  issues = 0
  pulls = 0
  Fbe.unmask_repos do |repo|
    owner, name = repo.split('/')
    json =
      begin
        Fbe.github_graph.total_issues_created(owner, name, fact.since)
      rescue GraphQL::Client::Error, Octokit::NotFound, Octokit::Deprecated => e
        $loog.info("Issues count not available for #{repo}: #{e.message}")
        next
      rescue Octokit::Forbidden, Octokit::TooManyRequests => e
        $loog.warn(
          "[#{$judge}] Access forbidden to issues count for #{repo} " \
          "(transient, will retry next cycle): #{e.class}: #{e.message}"
        )
        next
      rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNRESET => e
        $loog.warn("[#{$judge}] Network error counting issues for #{repo}: #{e.message}")
        next
      end
    issues += json['issues'] + json['pulls']
    pulls += json['pulls']
  end
  {
    total_issues_created: issues,
    total_pulls_submitted: pulls
  }
end
