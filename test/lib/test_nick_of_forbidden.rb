# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

# Reproduction for hypothesis H2.c (#131-class Forbidden bug verification).
# Proves Jp.nick_of (lib/nick_of.rb:14) propagates Octokit::Forbidden unrescued.
# The helper rescues NotFound + Deprecated but not Forbidden — cascade affects
# who-has-name, who-is-alive, eliminate-ghosts (H3 hypotheses).
# Lives on feature/forbidden-rescue-verification branch — NOT for upstream as-is.

require_relative '../test__helper'
require_relative '../../lib/nick_of'

class TestNickOfForbidden < Jp::Test
  def test_nick_of_propagates_forbidden_when_user_lookup_returns_403
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github(
      'https://api.github.com/user/29139614',
      status: 403,
      body: { message: 'Resource not accessible by integration' }
    )
    # Jp.nick_of internally calls Fbe.octo, which needs $options/$global set
    $options = Judges::Options.new({})
    $global = {}
    $loog = Loog::NULL
    exception = assert_raises(Octokit::Forbidden) do
      Jp.nick_of(29139614, loog: Loog::NULL)
    end
    assert_match(/Resource not accessible by integration/, exception.message)
  end
end
