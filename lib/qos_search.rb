# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require_relative 'jp'

def Jp.qoreset
  @offquota = false
end

def Jp.qosearch(query, kind: :issues, **)
  return if @offquota || Fbe.octo.off_quota?
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
    $loog.warn("[#{$judge}] GitHub Search API quota info unavailable, stopping QoS search calls")
    return
  end
  if left.zero?
    @offquota = true
    $loog.info('Too much GitHub Search API quota consumed already (0 left)')
    return
  end
  case kind
  when :issues then Fbe.octo.search_issues(query, **)
  when :commits then Fbe.octo.search_commits(query, **)
  else raise(ArgumentError, "Unknown search kind: #{kind}")
  end
rescue Octokit::TooManyRequests => e
  @offquota = true
  $loog.warn("[#{$judge}] GitHub Search API quota exhausted, stopping QoS search calls: #{e.message}")
  nil
rescue Octokit::Unauthorized => e
  @offquota = true
  $loog.warn("[#{$judge}] GitHub API token seems to be invalid or expired, stopping QoS search calls: #{e.message}")
  nil
end
