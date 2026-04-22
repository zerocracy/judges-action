# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

# Reproduction for hypothesis H2.b (#131-class Forbidden bug verification).
# Proves revive-user.rb:16 propagates Octokit::Forbidden unrescued — its rescue
# clause catches NotFound + Deprecated but not Forbidden.
# Lives on feature/forbidden-rescue-verification branch — NOT for upstream as-is.

require 'factbase'
require 'octokit'
require_relative '../test__helper'

class TestReviveUserForbidden < Jp::Test
  using SmartFactbase

  def test_revive_user_propagates_forbidden_when_user_lookup_returns_403
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github(
      'https://api.github.com/user/29139614',
      status: 403,
      body: { message: 'Resource not accessible by integration' }
    )
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-merged', repository: 42, issue: 44,
            who: 29139614, where: 'github', stale: 'who')
    exception = assert_raises(Octokit::Forbidden) do
      load_it('revive-user', fb)
    end
    assert_match(/Resource not accessible by integration/, exception.message)
  end
end
