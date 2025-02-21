# frozen_string_literal: true

# MIT License
#
# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/regularly'
require_relative '../../lib/incremate'

Fbe.regularly('scope', 'qod_interval', 'qod_days') do |f|
  Jp.incremate(f, __dir__, 'total')
end
