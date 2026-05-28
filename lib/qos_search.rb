# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'octokit'
require_relative 'jp'

Jp::SEARCH_WINDOW_SECONDS = 60
Jp::SEARCH_WINDOW_BUDGET = 25

def Jp.qoreset
  @offquota = false
  @scount = 0
  @swstart = nil
end

def Jp.qosearch(query, **options)
  return if @offquota || Fbe.octo.off_quota?
  now = Time.now
  if @swstart.nil? || (now - @swstart) >= Jp::SEARCH_WINDOW_SECONDS
    @swstart = now
    @scount = 0
  end
  if @scount >= Jp::SEARCH_WINDOW_BUDGET
    $loog.info(
      'Approaching GitHub Search API per-minute limit ' \
      "(#{@scount} calls in #{Integer(now - @swstart, exception: false) || 0}s), deferring this QoS search call"
    )
    return
  end
  @scount += 1
  found = Fbe.octo.search_issues(query, options)
  left = Fbe.octo.rate_limit.remaining
  if left.zero?
    @offquota = true
    $loog.info('Too much GitHub API quota consumed already (0 left)')
  end
  found
rescue Octokit::TooManyRequests => e
  @offquota = true
  $loog.warn("[#{$judge}] GitHub Search API quota exhausted, stopping QoS search calls: #{e.message}")
  nil
end
