# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'time'
require_relative 'jp'

def Jp.today
  v = ENV.fetch('TODAY', nil)
  if v.nil? || v.empty?
    Time.now.utc
  else
    Time.parse(v)
  end
end
