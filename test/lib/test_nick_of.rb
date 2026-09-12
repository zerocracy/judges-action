# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative '../../lib/nick_of'
require_relative '../fake_github'
require_relative '../test__helper'

class TestNickOf < Jp::Test
  def test_propagates_error_on_forbidden_user_lookup
    $options = Judges::Options.new({})
    $global = {}
    $loog = Loog::NULL
    Jp::FakeGithub.new(
      'GET /rate_limit' => { rate: { remaining: 222 } },
      'GET /user/29139614' => [403, { message: 'Resource not accessible by integration' }]
    ).run do
      assert_raises(Fbe::Error) { Jp.nick_of(29_139_614, loog: Loog::NULL) }
    end
  end

  def test_propagates_error_on_not_found_user_lookup
    $options = Judges::Options.new({})
    $global = {}
    $loog = Loog::NULL
    Jp::FakeGithub.new(
      'GET /rate_limit' => { rate: { remaining: 222 } },
      'GET /user/29139614' => [404, { message: 'Not Found' }]
    ).run do
      assert_raises(Fbe::Error) { Jp.nick_of(29_139_614, loog: Loog::NULL) }
    end
  end
end
