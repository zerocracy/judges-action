# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

# Reproduction for hypothesis H3.c (#131-class Forbidden bug verification).
# Proves eliminate-ghosts.rb propagates Octokit::Forbidden via its Jp.nick_of
# dependency. Triggered by any fact with `who` that the judge classifies.
# Lives on feature/forbidden-rescue-verification branch — NOT for upstream as-is.

require 'factbase'
require 'octokit'
require_relative '../test__helper'

class TestEliminateGhostsForbidden < Jp::Test
  using SmartFactbase

  def test_eliminate_ghosts_propagates_forbidden_via_nick_of
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github(
      'https://api.github.com/user/29139614',
      status: 403,
      body: { message: 'Resource not accessible by integration' }
    )
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, issue: 44,
            who: 29139614, where: 'github')
    exception = assert_raises(Octokit::Forbidden) do
      load_it('eliminate-ghosts', fb)
    end
    assert_match(/Resource not accessible by integration/, exception.message)
  end
end
