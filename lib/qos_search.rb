# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'octokit'
require_relative 'jp'

def Jp.qoreset
  @offquota = false
end

def Jp.qosearch(query, **options)
  return if @offquota || Fbe.octo.off_quota?
  found = Fbe.octo.search_issues(query, options)
  left = Fbe.octo.rate_limit.remaining
  if left.zero?
    @offquota = true
    $loog.info('Too much GitHub Search API quota consumed already (0 left)')
  end
  found
rescue Octokit::TooManyRequests => e
  @offquota = true
  $loog.warn("[#{$judge}] GitHub Search API quota exhausted, stopping QoS search calls: #{e.message}")
  nil
end
