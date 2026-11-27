# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'date'
require 'time'
require_relative 'jp'

def Jp.today
  v = ENV.fetch('TODAY', nil)
  if v.nil? || v.strip.empty?
    Time.now.utc
  else
    DateTime.parse(v).to_time.utc # rubocop:disable Style/DateTime
  end
end
