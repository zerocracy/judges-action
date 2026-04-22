# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

# Reproduction for hypothesis H3.a (#131-class Forbidden bug verification).
# Proves who-has-name.rb propagates Octokit::Forbidden via its Jp.nick_of
# dependency: nick_of's rescue catches NotFound + Deprecated but not Forbidden,
# so the exception escapes the judge.
# Lives on feature/forbidden-rescue-verification branch — NOT for upstream as-is.

require 'factbase'
require 'octokit'
require_relative '../test__helper'

class TestWhoHasNameForbidden < Jp::Test
  using SmartFactbase

  def test_who_has_name_propagates_forbidden_via_nick_of
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github(
      'https://api.github.com/user/29139614',
      status: 403,
      body: { message: 'Resource not accessible by integration' }
    )
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-merged', repository: 42, issue: 44,
            who: 29139614, where: 'github')
    exception = assert_raises(Octokit::Forbidden) do
      load_it('who-has-name', fb)
    end
    assert_match(/Resource not accessible by integration/, exception.message)
  end
end
