# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'faraday'
require 'fbe/octo'
require_relative 'jp'

Jp::SEARCH_WINDOW_SECONDS = 60
Jp::SEARCH_WINDOW_BUDGET = 25

def Jp.qoreset
  @offquota = false
  @offquotatime = nil
end

def Jp.qosearch(query, method: :search_issues, **)
  jg = $judge
  if @offquota
    return if @offquotatime && (Time.now - @offquotatime) < Jp::SEARCH_WINDOW_SECONDS
    @offquota = false
    @offquotatime = nil
  end
  now = Time.now
  if @swstart.nil? || (now - @swstart) >= Jp::SEARCH_WINDOW_SECONDS
    @swstart = now
    @scount = 0
  end
  if @scount >= Jp::SEARCH_WINDOW_BUDGET
    rest = Jp::SEARCH_WINDOW_SECONDS - (now - @swstart)
    $loog.info(
      "[#{jg}] Search API budget of #{Jp::SEARCH_WINDOW_BUDGET} calls " \
      "per #{Jp::SEARCH_WINDOW_SECONDS}s is spent, sleeping #{rest.ceil}s"
    )
    sleep(rest)
    @swstart = Time.now
    @scount = 0
  end
  octo = Fbe.octo
  left = nil
  json = nil
  begin
    json = octo.get('/rate_limit')
  rescue NoMethodError => e
    raise unless e.name == :get
    left = octo.rate_limit.remaining
  rescue Fbe::OffQuota => e
    $loog.info("[#{jg}] Not searching, the quota is spent: #{e.message}")
    return
  end
  if json
    json = JSON.parse(json, symbolize_names: true) if json.is_a?(String)
    left = json.dig(:resources, :search, :remaining)
  end
  if left.nil?
    @offquota = true
    @offquotatime = Time.now
    $loog.warn("[#{jg}] GitHub Search API quota info unavailable, stopping search calls")
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
  Fbe.octo.with_disable_auto_paginate { |octo| octo.__send__(method, query, **) }
rescue Octokit::Forbidden => e
  @offquota = true
  @offquotatime = Time.now
  $loog.warn("[#{jg}] GitHub Search API quota exhausted, stopping search calls: #{e.message}")
  nil
rescue Octokit::ServerError, Faraday::ConnectionFailed, Faraday::TimeoutError,
  Net::OpenTimeout, Net::ReadTimeout, SocketError,
  Errno::ECONNRESET, Errno::ETIMEDOUT => e
  $loog.warn("[#{jg}] Transient error in search API call (will retry next cycle): #{e.class}: #{e.message}")
  nil
end
