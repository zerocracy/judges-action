# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require_relative 'jp'

Jp::SEARCH_WINDOW_SECONDS = 60
Jp::SEARCH_WINDOW_BUDGET = 25

def Jp.qoreset
  @offquota = {}
  @offquotatime = {}
  @scount = {}
  @swstart = {}
end

def Jp.qosearch(query, method: :search_issues, **)
  jg = $judge
  @offquota = {} unless @offquota.is_a?(Hash)
  @offquotatime = {} unless @offquotatime.is_a?(Hash)
  @scount = {} unless @scount.is_a?(Hash)
  @swstart = {} unless @swstart.is_a?(Hash)
  if @offquota[jg]
    return if @offquotatime[jg] && (Time.now - @offquotatime[jg]) < Jp::SEARCH_WINDOW_SECONDS
    @offquota[jg] = false
    @offquotatime[jg] = nil
  end
  return if Fbe.octo.off_quota?
  now = Time.now
  if @swstart[jg].nil? || (now - @swstart[jg]) >= Jp::SEARCH_WINDOW_SECONDS
    @swstart[jg] = now
    @scount[jg] = 0
  end
  if @scount[jg] >= Jp::SEARCH_WINDOW_BUDGET
    $loog.info("[#{jg}] Search API per-minute budget exceeded (#{Jp::SEARCH_WINDOW_BUDGET}/#{Jp::SEARCH_WINDOW_SECONDS}s)")
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
    @offquota[jg] = true
    @offquotatime[jg] = Time.now
    $loog.warn("[#{jg}] GitHub Search API quota info unavailable, stopping search calls")
    return
  end
  if left.zero?
    @offquota[jg] = true
    @offquotatime[jg] = Time.now
    $loog.info('Too much GitHub Search API quota consumed already (0 left)')
    return
  end
  @scount[jg] += 1
  raise(RuntimeError, "Unsafe search method: #{method}") unless
    %i[search_issues search_code search_commits].include?(method)
  Fbe.octo.__send__(method, query, **)
rescue Octokit::TooManyRequests => e
  @offquota[jg] = true
  @offquotatime[jg] = Time.now
  $loog.warn("[#{jg}] GitHub Search API quota exhausted, stopping search calls: #{e.message}")
  nil
rescue Octokit::ServerError,
       Net::OpenTimeout, Net::ReadTimeout, SocketError,
       Errno::ECONNRESET, Errno::ETIMEDOUT => e
  $loog.warn("[#{jg}] Transient error in search API call (will retry next cycle): #{e.class}: #{e.message}")
  nil
end
