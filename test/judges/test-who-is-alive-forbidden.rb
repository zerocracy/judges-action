# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

# Reproduction for hypothesis H3.b (#131-class Forbidden bug verification).
# Proves who-is-alive.rb propagates Octokit::Forbidden via its Jp.nick_of
# dependency. Triggered by an aged who-has-name fact (>2 days old) that the
# judge tries to refresh.
# Lives on feature/forbidden-rescue-verification branch — NOT for upstream as-is.

require 'factbase'
require 'octokit'
require_relative '../test__helper'

class TestWhoIsAliveForbidden < Jp::Test
  using SmartFactbase

  def test_who_is_alive_propagates_forbidden_via_nick_of
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github(
      'https://api.github.com/user/29139614',
      status: 403,
      body: { message: 'Resource not accessible by integration' }
    )
    fb = Factbase.new
    fb.with(_id: 1, what: 'who-has-name', who: 29139614, where: 'github',
            when: Time.now - (3 * 86_400), name: 'someone')
    exception = assert_raises(Octokit::Forbidden) do
      load_it('who-is-alive', fb)
    end
    assert_match(/Resource not accessible by integration/, exception.message)
  end
end
