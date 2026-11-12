# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../../lib/ghost'
require_relative '../test__helper'

class TestAuthorGhost < Jp::Test
  using SmartFactbase

  def test_identifies_only_the_ghost_account
    assert(Jp.ghost?(10_137))
    refute(Jp.ghost?(44))
    refute(Jp.ghost?(nil))
  end

  def test_does_not_credit_an_issue_to_the_ghost_account
    recover('issue')
  end

  def test_does_not_credit_a_pull_to_the_ghost_account
    recover('pull')
  end

  private

  def recover(kind)
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    [[45, 10_137, 'ghost'], [46, 44, 'user']].each do |number, id, login|
      body = { number:, user: { id:, login: }, created_at: '2025-09-27 06:03:16 UTC' }
      if kind == 'pull'
        body[:pull_request] = { url: "https://api.github.com/repos/foo/foo/pulls/#{number}" }
        stub_github("https://api.github.com/repos/foo/foo/pulls/#{number}", body: { head: { ref: 'feature' } })
      end
      stub_github("https://api.github.com/repos/foo/foo/issues/#{number}", body:)
      stub_github("https://api.github.com/user/#{id}", body: { id:, login:, type: 'User' })
    end
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, issue: 44, where: 'github')
      .with(_id: 2, what: 'issue-was-opened', repository: 42, issue: 47, where: 'github')
    load_it('find-missing-issues', fb)
    gone = fb.pick(issue: 45)
    assert_nil(gone['who'])
    assert_equal('who', gone.stale)
    assert_equal("#{kind}-was-opened", gone.what)
    assert_includes(gone.details, 'a user who has deleted the account')
    live = fb.pick(issue: 46)
    assert_equal(44, live.who)
    assert_nil(live['stale'])
    assert_equal("#{kind}-was-opened", live.what)
    assert_not_requested(:get, 'https://api.github.com/user/10137')
  end
end
