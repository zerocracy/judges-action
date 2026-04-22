# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative '../test__helper'
require_relative '../../lib/nick_of'

class TestNickOf < Jp::Test
  def test_returns_nil_when_user_lookup_returns_403
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github(
      'https://api.github.com/user/29139614',
      status: 403,
      body: { message: 'Resource not accessible by integration' }
    )
    $options = Judges::Options.new({})
    $global = {}
    $loog = Loog::NULL
    assert_nil(Jp.nick_of(29_139_614, loog: Loog::NULL))
  end
end