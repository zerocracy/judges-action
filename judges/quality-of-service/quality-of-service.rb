# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/regularly'
require_relative '../../lib/incremate'

Fbe.regularly('quality', 'qos_interval', 'qos_days') do |f|
  Jp.incremate(f, __dir__, 'average')
end
