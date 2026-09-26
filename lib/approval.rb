# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'time'
require_relative 'jp'

def Jp.stamp(review)
  moment = review[:submitted_at]
  moment.is_a?(Time) ? moment : Time.parse(moment.to_s)
end

def Jp.approval(reviews, closed = nil)
  picked = reviews.nil? ? [] : reviews
  unless closed.nil?
    edge = closed.is_a?(Time) ? closed : Time.parse(closed.to_s)
    before = picked.select { |r| Jp.stamp(r) <= edge }
    picked = before unless before.empty?
  end
  approved = picked.select { |r| r[:state] == 'APPROVED' }
  picked = approved unless approved.empty?
  picked.max_by { |r| Jp.stamp(r) }
end
