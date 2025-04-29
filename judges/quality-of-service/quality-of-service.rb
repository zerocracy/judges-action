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
  on '(eq what "quality-of-service")'
  consider do |f|
    Jp.incremate(f, __dir__, 'average', avoid_duplicate: true)
  end
end
