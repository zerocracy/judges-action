# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'octokit'
require_relative 'jp'

def Jp.qoreset
  @offquota = false
end

def Jp.qosearch(query, **)
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
  Fbe.octo.search_issues(query, **).tap do
    origin = octo.instance_eval { @o }.instance_variable_get(:@origin).instance_variable_get(:@origin)
    if origin.respond_to?(:last_response)
      left = origin.last_response&.headers&.fetch('x-ratelimit-remaining', nil)
      @offquota = true if left && Integer(left, 10).zero?
    end
  end
rescue Octokit::TooManyRequests => e
  @offquota = true
  $loog.warn("[#{$judge}] GitHub Search API quota exhausted, stopping QoS search calls: #{e.message}")
  nil
end
