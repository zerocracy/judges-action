# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'json'
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
  octo = Fbe.octo
  left = nil
  begin
    json = octo.get('/rate_limit')
    json = JSON.parse(json, symbolize_names: true) if json.is_a?(String)
    left = json.dig(:resources, :search, :remaining)
  rescue NoMethodError => e
    raise unless e.name == :get
  end
  left ||= octo.rate_limit.remaining
  if left.zero?
    @offquota = true
    $loog.info('Too much GitHub Search API quota consumed already (0 left)')
    return
  end
  @scount += 1
  Fbe.octo.search_issues(query, options)
rescue Octokit::TooManyRequests => e
  @offquota = true
  $loog.warn("[#{$judge}] GitHub Search API quota exhausted, stopping QoS search calls: #{e.message}")
  nil
end
