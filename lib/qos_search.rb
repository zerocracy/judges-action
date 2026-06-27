# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require_relative 'jp'

Jp::SEARCH_WINDOW_SECONDS = 60
Jp::SEARCH_WINDOW_BUDGET = 25

def Jp.qoreset
  @offquota = false
  @scount = 0
  @swstart = nil
end

def Jp.qosearch(query, method: :search_issues, **)
  return if @offquota || Fbe.octo.off_quota?
  now = Time.now
  if @swstart.nil? || (now - @swstart) >= Jp::SEARCH_WINDOW_SECONDS
    @swstart = now
    @scount = 0
  end
  if @scount >= Jp::SEARCH_WINDOW_BUDGET
    $loog.info("[#{$judge}] Search API per-minute budget exceeded (#{Jp::SEARCH_WINDOW_BUDGET}/#{Jp::SEARCH_WINDOW_SECONDS}s)")
    return
  end
  octo = Fbe.octo
  left = nil
  if octo.respond_to?(:get)
    json = octo.get('/rate_limit')
    json = JSON.parse(json, symbolize_names: true) if json.is_a?(String)
    left = json.dig(:resources, :search, :remaining)
  else
    left = octo.rate_limit.remaining
  end
  if left.nil?
    @offquota = true
    $loog.warn("[#{$judge}] GitHub Search API quota info unavailable, stopping search calls")
    return
  end
  if left.zero?
    @offquota = true
    $loog.info('Too much GitHub Search API quota consumed already (0 left)')
    return
  end
  @scount += 1
  Fbe.octo.__send__(method, query, **)
rescue Octokit::TooManyRequests => e
  @offquota = true
  $loog.warn("[#{$judge}] GitHub Search API quota exhausted, stopping search calls: #{e.message}")
  nil
end
