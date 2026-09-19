# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'time'
require_relative 'jp'

# The review that let the pull merge, which is the last approval submitted
# before the pull was closed. GitHub returns reviews oldest first, so the
# first one is usually a "changes requested" from long before the work was
# finished. When nothing was approved, the last review is taken instead.
def Jp.merging_review(reviews, closed = nil)
  return nil if reviews.nil? || reviews.empty?
  stamp = ->(r) { r[:submitted_at].is_a?(Time) ? r[:submitted_at] : Time.parse(r[:submitted_at].to_s) }
  picked = reviews
  unless closed.nil?
    edge = closed.is_a?(Time) ? closed : Time.parse(closed.to_s)
    before = picked.select { |r| stamp.call(r) <= edge }
    picked = before unless before.empty?
  end
  approved = picked.select { |r| r[:state] == 'APPROVED' }
  picked = approved unless approved.empty?
  picked.max_by { |r| stamp.call(r) }
end
