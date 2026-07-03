# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative '../../lib/nick_of'
require_relative '../test__helper'

class TestNickOf < Jp::Test
  def test_raises_on_forbidden_user_lookup
    rate_limit_up
    $options = Judges::Options.new({})
    $global = {}
    $loog = Loog::NULL
    VCR.use_cassette('lib/nick-of/forbidden-user-lookup') do
      assert_raises(Octokit::Forbidden) { Jp.nick_of(29_139_614, loog: Loog::NULL) }
    end
  end
end
