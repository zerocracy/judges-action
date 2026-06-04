# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'

def total_releases_published(fact)
  total = 0
  Fbe.unmask_repos do |repo|
    owner, name = repo.split('/')
    total +=
      begin
        Fbe.github_graph.total_releases_published(owner, name, fact.since)['releases']
      rescue GraphQL::Client::Error, Octokit::NotFound, Octokit::Deprecated => e
        $loog.info("Releases count not available for #{repo}: #{e.message}")
        next
      rescue Octokit::Forbidden => e
        $loog.warn(
          "[#{$judge}] Access forbidden to releases count for #{repo} " \
          "(transient, will retry next cycle): #{e.class}: #{e.message}"
        )
        next
      rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNRESET => e
        $loog.warn("[#{$judge}] Network error counting releases for #{repo}: #{e.message}")
        next
      end
  end
  { total_releases_published: total }
end
