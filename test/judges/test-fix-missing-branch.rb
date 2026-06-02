# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../test__helper'

class TestFixMissingBranch < Jp::Test
  using SmartFactbase

  def test_finds_branch_via_pull_request
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, full_name: 'foo/foo' })
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/44',
      body: {
        number: 44,
        state: 'open',
        head: { ref: 'feature-branch', sha: 'abc123' }
      }
    )
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-opened', repository: 42, issue: 44, where: 'github')
    load_it('fix-missing-branch', fb)
    f = fb.query('(eq issue 44)').each.first
    refute_nil(f)
    assert_equal('feature-branch', f['branch'].first, 'branch must be extracted from pull_request.head.ref')
    assert_nil(f['stale'], 'fact must NOT be marked stale when branch is found')
  end

  def test_rescues_forbidden_on_pull_request_lookup
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, full_name: 'foo/foo' })
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/44',
      status: 403,
      body: { message: 'Resource not accessible by integration' }
    )
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-opened', repository: 42, issue: 44, where: 'github')
    load_it('fix-missing-branch', fb)
    f = fb.query('(eq issue 44)').each.first
    refute_nil(f)
    assert_nil(f['stale'],
               '403 is transient — fact must NOT be marked stale; next cycle will retry the pull_request lookup')
  end
end
