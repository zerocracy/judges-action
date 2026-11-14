# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'octokit'
require 'open3'
require_relative '../../lib/patches/octokit_throttling'
require_relative '../test__helper'

class TestOctokitThrottling < Jp::Test
  def test_turns_a_throttled_answer_into_too_many_requests
    [403, 429].each do |status|
      assert_kind_of(Octokit::TooManyRequests, error(status), "status #{status}")
    end
  end

  def test_leaves_the_other_answers_alone
    {
      404 => Octokit::NotFound,
      401 => Octokit::Unauthorized,
      422 => Octokit::UnprocessableEntity,
      500 => Octokit::InternalServerError
    }.each do |status, klass|
      e = error(status)
      assert_kind_of(klass, e, "status #{status}")
      refute_kind_of(Octokit::TooManyRequests, e, "status #{status}")
    end
  end

  def test_turns_a_429_into_too_many_requests_in_add_review_comments_alone
    judge = File.expand_path('../../judges/add-review-comments/add-review-comments.rb', __dir__)
    libs =
      File.read(judge).scan(/^require_relative '([^']+)'$/).map do |l|
        File.expand_path(l.first, File.dirname(judge))
      end
    script = [
      *libs.map { |l| "require #{l.inspect}" },
      "e = Octokit::Error.from_response({ status: 429, body: '{}', response_headers: {} })",
      'print e.class'
    ].join("\n")
    out, status = Open3.capture2e(Gem.ruby, '-e', script)
    assert_predicate(status, :success?, out)
    assert_equal('Octokit::TooManyRequests', out.strip.lines.last, out)
  end

  private

  def error(status)
    Octokit::Error.from_response(
      {
        status:,
        body: '{"message":"You have exceeded a secondary rate limit"}',
        response_headers: { 'content-type' => 'application/json' }
      }
    )
  end
end
