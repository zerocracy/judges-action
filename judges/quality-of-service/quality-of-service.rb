# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

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
