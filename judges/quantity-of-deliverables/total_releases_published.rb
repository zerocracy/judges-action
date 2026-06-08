# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/github_graph'
require 'fbe/octo'
require 'fbe/unmask_repos'
require 'net/http'
require 'octokit'

def total_releases_published(fact)
  {
    total_releases_published: Fbe.unmask_repos.sum do |repo|
      owner, name = repo.split('/')
      begin
        Fbe.github_graph.total_releases_published(owner, name, fact.since)['releases']
      rescue GraphQL::Client::Error, Octokit::Forbidden, Net::OpenTimeout, Net::ReadTimeout,
        SocketError, Errno::ECONNRESET, Errno::ETIMEDOUT => e
        $loog.warn(
          "[#{$judge}] Can't count released projects in #{repo} " \
          "(transient, will retry next cycle): #{e.class}: #{e.message}"
        )
        next 0
      end
    end
  }
end
