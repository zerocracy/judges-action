# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

# Judge that calculates various quality metrics for GitHub repositories.
# Regularly collects quality of service metrics such as average issue lifetime,
# build success rate, review time, pull request HoC size, release interval,
# backlog size, triage time, and other quality indicators. Uses the incremate helper
# to collect metrics from supporting files with average_* prefix.
#
# @see ../../lib/incremate.rb Implementation of the incremate helper
# @see https://github.com/yegor256/fbe/blob/master/lib/fbe/regularly.rb Implementation of Fbe.regularly
# @see https://github.com/yegor256/fbe/blob/master/lib/fbe/conclude.rb Implementation of Fbe.conclude
# @note Each supporting file with average_* prefix implements a specific metric calculation

require 'fbe/regularly'
require 'fbe/conclude'
require_relative '../../lib/incremate'

Fbe.regularly('quality', 'qos_interval', 'qos_days') do |f|
  Jp.incremate(f, __dir__, 'average')
end

Fbe.conclude do
  quota_aware
  on '(and (eq what "quality-of-service") (exists when) (absent since))'
  consider do |f|
    pmp = Fbe.fb.query("(and (eq what 'pmp') (eq area 'quality') (exists qos_days))").each.to_a.first
    f.since = f.when - (((!pmp.nil? && pmp['qos_days']&.first) || 28) * 24 * 60 * 60)
  end
end

Fbe.conclude do
  quota_aware
  on '(and (eq what "quality-of-service") (exists since))'
  consider do |f|
    Jp.incremate(f, __dir__, 'average', avoid_duplicate: true)
  end
end
