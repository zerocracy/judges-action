# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2025 Yegor Bugayenko
# License:: MIT
class TestCodeWasReviewed < Jp::Test
  using SmartFactbase

  def test_find_absent_code_was_reviewed_facts
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/44',
      body: {
        id: 50, number: 44, user: { id: 421, login: 'user' },
        created_at: Time.parse('2025-09-01 15:35:30 UTC'), additions: 12, deletions: 5
      }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/44/reviews?per_page=100',
      body: [
        { id: 49_111, user: { id: 422, login: 'user2' }, submitted_at: Time.parse('2025-09-02 10:39:20 UTC') }
      ]
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/issues/44/comments?per_page=100',
      body: [
        { id: 48_119, user: { id: 421, login: 'user' } },
        { id: 48_120, user: { id: 422, login: 'user2' } }
      ]
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/44/reviews/49111/comments?per_page=100',
      body: [
        { id: 47_120, user: { id: 422, login: 'user2' } },
        { id: 47_121, user: { id: 422, login: 'user2' } },
        { id: 47_122, user: { id: 422, login: 'user2' } }
      ]
    )
    stub_github('https://api.github.com/user/421', body: {  id: 421, login: 'user1' })
    stub_github('https://api.github.com/user/422', body: {  id: 422, login: 'user2' })
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/45',
      body: {
        id: 50, number: 45, user: { id: 421, login: 'user' },
        created_at: Time.parse('2025-09-02 17:05:30 UTC'), additions: 2, deletions: 8
      }
    )
    stub_github('https://api.github.com/repos/foo/foo/pulls/45/reviews?per_page=100', body: [])
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-closed', repository: 42, issue: 40, where: 'github')
      .with(_id: 2, what: 'code-was-reviewed', repository: 42, issue: 40, where: 'github')
      .with(_id: 3, what: 'pull-was-closed', repository: 42, issue: 44, where: 'github')
      .with(_id: 4, what: 'pull-was-merged', repository: 42, issue: 45, where: 'github')
    load_it('code-was-reviewed', fb)
    assert_equal(5, fb.all.size)
    assert(
      fb.one?(
        what: 'code-was-reviewed', where: 'github', repository: 42, issue: 44, who: 422, hoc: 17, author: 421,
        when: Time.parse('2025-09-02 10:39:20 UTC'), comments: 2, review_comments: 3, seconds: 68_630,
        details: 'The pull request foo/foo#44 with 17 HoC created by @user1 ' \
                 'was reviewed by @user2 after 19h3m and 3 comments.'
      )
    )
  end
end
