# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require_relative 'jp'

Jp::SEARCH_WINDOW_SECONDS = 60
Jp::SEARCH_WINDOW_BUDGET = 25

def Jp.qoreset
  @offquota = false
  @offquotatime = nil
  @scount = 0
  @swstart = nil
end

def Jp.qosearch(query, method: :search_issues, **)
  if @offquota
    return if @offquotatime && (Time.now - @offquotatime) < Jp::SEARCH_WINDOW_SECONDS
    @offquota = false
    @offquotatime = nil
  end
  return if Fbe.octo.off_quota?
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
  begin
    json = octo.get('/rate_limit')
    json = JSON.parse(json, symbolize_names: true) if json.is_a?(String)
    left = json.dig(:resources, :search, :remaining)
  rescue NoMethodError => e
    raise unless e.name == :get
    left = octo.rate_limit.remaining
  end
  if left.nil?
    @offquota = true
    @offquotatime = Time.now
    $loog.warn("[#{$judge}] GitHub Search API quota info unavailable, stopping search calls")
    return
  end
  if left.zero?
    @offquota = true
    @offquotatime = Time.now
    $loog.info('Too much GitHub Search API quota consumed already (0 left)')
    return
  end
  @scount += 1
  raise(RuntimeError, "Unsafe search method: #{method}") unless
    %i[search_issues search_code search_commits].include?(method)
  Fbe.octo.__send__(method, query, **)
rescue Octokit::TooManyRequests => e
  @offquota = true
  @offquotatime = Time.now
  $loog.warn("[#{$judge}] GitHub Search API quota exhausted, stopping search calls: #{e.message}")
  nil
rescue Octokit::ServerError,
  Net::OpenTimeout, Net::ReadTimeout, SocketError,
  Errno::ECONNRESET, Errno::ETIMEDOUT => e
  $loog.warn("[#{$judge}] Transient error in search API call (will retry next cycle): #{e.class}: #{e.message}")
  nil
end
