# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'octokit'
require 'factbase'
require 'judges/options'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024 Yegor Bugayenko
# License:: MIT
class TestFindMissingOpenIssues < Jp::Test
  using SmartFactbase

  def test_find_missing_open_issues_in_fb
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_github('https://api.github.com/repos/foo/foo/issues/142',
                body: {
                  id: 655, number: 142, user: { login: 'user2', id: 422, type: 'User' },
                  created_at: Time.parse('2025-06-01 12:00:55 UTC'), closed_at: Time.parse('2025-06-02 15:00:00 UTC')
                })
    stub_github('https://api.github.com/user/422', body: { id: 422, login: 'user2' })
    stub_github('https://api.github.com/repos/foo/foo/issues/143',
                body: {
                  id: 855, number: 143, user: { login: 'user2', id: 422, type: 'User' },
                  pull_request: { merged_at: nil, head: { ref: 'master' } },
                  created_at: Time.parse('2025-05-29 17:00:55 UTC'), closed_at: Time.parse('2025-05-01 18:20:00 UTC')
                })
    stub_github('https://api.github.com/repos/foo/foo/issues/50',
                body: {
                  id: 755, number: 50, user: { login: 'user2', id: 422, type: 'User' },
                  created_at: Time.parse('2025-05-29 12:10:55 UTC'), closed_at: Time.parse('2025-06-01 15:05:00 UTC')
                })
    stub_github('https://api.github.com/repos/foo/foo/issues/52',
                body: {
                  id: 875, number: 52, user: { login: 'user2', id: 422, type: 'User' },
                  pull_request: { merged_at: nil, head: { ref: 'master' } },
                  created_at: Time.parse('2025-05-28 17:40:55 UTC'), closed_at: Time.parse('2025-06-01 18:25:00 UTC')
                })
    stub_github('https://api.github.com/repos/foo/foo/issues/404',
                status: 404,
                body: {
                  status: '404', message: 'Not Found',
                  documentation_url: 'https://docs.github.com/rest/issues/issues#get-an-issue'
                })
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, issue: 40, where: 'github')
      .with(_id: 2, what: 'issue-was-closed', repository: 42, issue: 40, where: 'github')
      .with(_id: 3, what: 'pull-was-opened', repository: 42, issue: 42, where: 'github')
      .with(_id: 4, what: 'pull-was-closed', repository: 42, issue: 42, where: 'github')
      .with(_id: 5, what: 'issue-was-opened', repository: 42, issue: 44, where: 'github')
      .with(_id: 6, what: 'pull-was-opened', repository: 42, issue: 45, where: 'github')
      .with(_id: 7, what: 'issue-was-closed', repository: 42, issue: 142, where: 'github')
      .with(_id: 8, what: 'pull-was-closed', repository: 42, issue: 143, where: 'github')
      .with(_id: 9, what: 'pull-was-closed', repository: 42, issue: 143, where: 'gitlab')
      .with(_id: 10, what: 'issue-was-assigned', repository: 42, issue: 50, where: 'github')
      .with(_id: 11, what: 'pull-was-merged', repository: 42, issue: 52, where: 'github')
      .with(_id: 12, what: 'pull-was-closed', repository: 42, issue: 404, where: 'github')
    load_it('find-missing-open-issues', fb)
    assert_equal(16, fb.all.size)
    assert_equal(4, fb.picks(what: 'issue-was-opened').size)
    assert_equal(2, fb.picks(what: 'issue-was-closed').size)
    assert_equal(4, fb.picks(what: 'pull-was-opened').size)
    assert_equal(4, fb.picks(what: 'pull-was-closed').size)
    assert_equal(1, fb.picks(what: 'issue-was-assigned').size)
    assert_equal(1, fb.picks(what: 'pull-was-merged').size)
    assert(fb.one?(what: 'issue-was-opened', repository: 42, issue: 142, where: 'github',
                   when: Time.parse('2025-06-01 12:00:55 UTC'), who: 422,
                   details: 'The issue foo/foo#142 has been opened by @user2.'))
    assert(fb.one?(what: 'pull-was-opened', repository: 42, issue: 143, where: 'github',
                   when: Time.parse('2025-05-29 17:00:55 UTC'), who: 422,
                   details: 'The pull foo/foo#143 has been opened by @user2.'))
    assert(fb.one?(what: 'issue-was-opened', repository: 42, issue: 50, where: 'github',
                   when: Time.parse('2025-05-29 12:10:55 UTC'), who: 422,
                   details: 'The issue foo/foo#50 has been opened by @user2.'))
    assert(fb.one?(what: 'pull-was-opened', repository: 42, issue: 52, where: 'github',
                   when: Time.parse('2025-05-28 17:40:55 UTC'), who: 422,
                   details: 'The pull foo/foo#52 has been opened by @user2.'))
    assert(fb.none?(what: 'pull-was-opened', repository: 42, issue: 404, where: 'github'))
    assert(fb.one?(what: 'issue-was-opened', repository: 42, issue: 40, where: 'github'))
    assert(fb.one?(what: 'pull-was-opened', repository: 42, issue: 42, where: 'github'))
    assert(fb.one?(what: 'issue-was-opened', repository: 42, issue: 44, where: 'github'))
    assert(fb.one?(what: 'pull-was-opened', repository: 42, issue: 45, where: 'github'))
    assert(fb.none?(what: 'pull-was-opened', repository: 42, issue: 143, where: 'gitlab'))
  end
end
