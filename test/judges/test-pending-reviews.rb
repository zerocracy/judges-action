# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'loog'
require 'time'
require_relative '../../judges/quality-of-service/some_review_time'
require_relative '../test__helper'

class TestPendingReviews < Jp::Test
  def test_counts_only_submitted_reviews
    moment = Time.iso8601('2026-10-02T00:00:00Z')
    approved = { state: 'APPROVED', user: { id: 11 }, submitted_at: moment - 14_400 }
    pending = { state: 'PENDING', user: { id: 12 }, submitted_at: nil }
    [[[], 0], [[approved], 1], [[pending], 0], [[approved, pending], 1]].each do |entries, count|
      fact = Factbase.new.insert
      fact.since = moment - (30 * 86_400)
      fact.when = moment
      pull = { number: 7, user: { id: 1 }, pull_request: { merged_at: moment - 7200 } }
      client = Object.new
      client.define_singleton_method(:off_quota?) { false }
      client.define_singleton_method(:pull_request_reviews) { |*| entries }
      client.define_singleton_method(:review_comments) { |*| [Object.new] }
      Fbe.stub(:unmask_repos, ->(&block) { block.call('acme/project') }) do
        Fbe.stub(:octo, client) do
          Jp.stub(:qosearch, { items: [pull] }) do
            result = some_review_time(fact)
            assert_equal([count], result[:some_reviews_per_pull])
            assert_equal([count], result[:some_reviewers_per_pull])
            assert_equal(count.zero? ? [] : [7200], result[:some_review_time])
            assert_equal([1], result[:some_review_size])
          end
        end
      end
    end
  end
end
