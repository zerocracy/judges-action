# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative '../../lib/repo_name_of'
require_relative '../test__helper'

class TestRepoNameOf < Jp::Test
  def setup
    WebMock.disable_net_connect!
    rate_limit_up
    $options = Judges::Options.new({})
    $global = {}
    $loog = Loog::NULL
    $judge = 'test-repo-name-of'
  end

  def test_returns_name_and_ok_on_success
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/bar' })
    name, status = Jp.repo_name_of(42, loog: Loog::NULL)
    assert_equal('foo/bar', name)
    assert_equal(:ok, status)
  end

  def test_returns_nil_and_lost_on_not_found
    stub_github('https://api.github.com/repositories/43', status: 404, body: { message: 'Not Found' })
    name, status = Jp.repo_name_of(43, loog: Loog::NULL)
    assert_nil(name)
    assert_equal(:lost, status)
  end

  def test_returns_nil_and_transient_on_forbidden
    stub_github(
      'https://api.github.com/repositories/44',
      status: 403,
      body: { message: 'Resource not accessible by integration' }
    )
    name, status = Jp.repo_name_of(44, loog: Loog::NULL)
    assert_nil(name)
    assert_equal(:transient, status)
  end
end
