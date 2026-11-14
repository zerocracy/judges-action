# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/pmp'
require_relative 'jp'

def Jp.qos_param(name, default = nil)
  Fbe.pmp.quality.public_send(name).value || default
rescue Fbe::Error
  default
end
