# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'
require_relative '../../lib/patches/fake_octokit'
require_relative '../../lib/patches/unmask_repos'

def total_releases_published(fact)
  releases = 0
  Fbe.unmask_repos do |repo|
    releases +=
      Fbe.octo.releases(repo).count do |r|
        next false if r[:draft] || r[:published_at].nil?
        r[:published_at] > fact.since && r[:published_at] <= fact.when
      end
  rescue Octokit::NotFound, Octokit::Deprecated => e
    $loog.info("Can't count releases in #{repo}: #{e.message}")
    next
  rescue Octokit::Forbidden => e
    $loog.warn(
      "[#{$judge}] Access forbidden to releases for #{repo} " \
      "(transient, will retry next cycle): #{e.class}: #{e.message}"
    )
    next
  rescue Octokit::ServerError, Faraday::TimeoutError, Faraday::ConnectionFailed => e
    $loog.warn(
      "[#{$judge}] Cannot count releases in #{repo}, the API failed " \
      "(transient, will retry next cycle): #{e.class}: #{e.message}"
    )
    next
  rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNRESET, Errno::ETIMEDOUT => e
    $loog.warn("[#{$judge}] Network error counting releases in #{repo}: #{e.message}")
    next
  end
  {
    total_releases_published: releases
  }
end
