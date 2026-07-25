# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/github_graph'
require 'fbe/octo'
require 'fbe/unmask_repos'

def total_releases_published(fact)
  releases = 0
  Fbe.unmask_repos do |repo|
    owner, name = repo.split('/')
    begin
      releases += Fbe.github_graph.total_releases_published(owner, name, fact.since)['releases']
    rescue GraphQL::Client::Error, Octokit::NotFound, Octokit::Deprecated => e
      $loog.info("Can't count releases in #{repo}: #{e.message}")
      next
    rescue Octokit::Forbidden, Octokit::TooManyRequests => e
      $loog.warn(
        "[#{$judge}] Can't count releases in #{repo} " \
        "(transient, will retry next cycle): #{e.class}: #{e.message}"
      )
      next
    rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNRESET, Errno::ETIMEDOUT => e
      $loog.warn("[#{$judge}] Network error counting releases in #{repo}: #{e.message}")
      next
    end
  end
  {
    total_releases_published: releases
  }
end
