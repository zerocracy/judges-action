# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../test__helper'

class TestCodeWasReviewed < Jp::Test
  using SmartFactbase

  def test_find_absent_code_was_reviewed_facts
    rate_limit_up
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-closed', repository: 42, issue: 40, where: 'github')
      .with(_id: 2, what: 'code-was-reviewed', repository: 42, issue: 40, where: 'github')
      .with(_id: 3, what: 'pull-was-closed', repository: 42, issue: 44, where: 'github')
      .with(_id: 4, what: 'pull-was-merged', repository: 42, issue: 45, where: 'github')
    VCR.use_cassette('code-was-reviewed/find-absent-code-was-reviewed-facts') do
      load_it('code-was-reviewed', fb)
    end
    assert_equal(5, fb.all.size)
    assert(
      fb.one?(
        what: 'code-was-reviewed', where: 'github', repository: 42, issue: 44, who: 422, hoc: 17, author: 421,
        when: Time.parse('2025-09-02 10:39:20 UTC'), comments: 2, review_comments: 3, seconds: 68_630,
        details:
          'The pull request foo/foo#44 with 17 HoC created by @user1 ' \
          'was reviewed by @user2 after 19h3m and 3 comments.'
      )
    )
  end

  def test_rescues_not_found_on_pull_request_lookup
    rate_limit_up
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-closed', repository: 42, issue: 77, where: 'github')
    VCR.use_cassette('code-was-reviewed/rescues-not-found-on-pull-request-lookup') do
      load_it('code-was-reviewed', fb)
    end
    assert(
      fb.one?(what: 'pull-was-closed', repository: 42, issue: 77, stale: 'issue'),
      'expected the sibling pull-was-closed fact to be marked stale by Jp.issue_was_lost ' \
      'after the unrescued 404 on Fbe.octo.pull_request'
    )
  end

  def test_rescues_forbidden_on_pull_request_lookup
    rate_limit_up
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-closed', repository: 42, issue: 88, where: 'github')
    VCR.use_cassette('code-was-reviewed/rescues-forbidden-on-pull-request-lookup') do
      load_it('code-was-reviewed', fb)
    end
    refute(
      fb.one?(what: 'issue-was-lost', where: 'github', repository: 42, issue: 88),
      'forbidden error must not produce an issue-was-lost tombstone'
    )
    refute(
      fb.one?(what: 'pull-was-closed', repository: 42, issue: 88, stale: 'issue'),
      'forbidden error must leave the original fact untouched'
    )
  end

  def test_rescues_deprecated_on_reviews_lookup
    rate_limit_up
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-closed', repository: 42, issue: 99, where: 'github')
    VCR.use_cassette('code-was-reviewed/rescues-deprecated-on-reviews-lookup') do
      load_it('code-was-reviewed', fb)
    end
    assert(
      fb.one?(what: 'pull-was-closed', repository: 42, issue: 99, stale: 'issue'),
      'deprecated reviews lookup must mark the sibling pull fact stale through Jp.issue_was_lost'
    )
  end

  def test_rescues_forbidden_on_reviews_lookup_and_continues
    rate_limit_up
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-closed', repository: 42, issue: 99, where: 'github')
      .with(_id: 2, what: 'pull-was-closed', repository: 42, issue: 100, where: 'github')
    VCR.use_cassette('code-was-reviewed/rescues-forbidden-on-reviews-lookup-and-continues') do
      load_it('code-was-reviewed', fb)
    end
    refute(
      fb.one?(what: 'pull-was-closed', repository: 42, issue: 99, stale: 'issue'),
      'forbidden reviews lookup must leave the original pull fact untouched'
    )
    assert(
      fb.one?(what: 'code-was-reviewed', repository: 42, issue: 100, who: 422, hoc: 7, author: 421),
      'forbidden reviews lookup must not abort later candidates in the same judge batch'
    )
  end
end
