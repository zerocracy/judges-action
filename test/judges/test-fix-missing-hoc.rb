# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../test__helper'

class TestFixMissingHoc < Jp::Test
  using SmartFactbase

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
    fb.with(_id: 1, what: 'pull-was-merged', repository: 42, issue: 44, where: 'github')
    load_it('fix-missing-hoc', fb)
    f = fb.query('(eq issue 44)').each.first
    refute_nil(f)
    assert_nil(f['hoc'], '403 is transient — fact must NOT receive hoc; next cycle will retry')
    assert_nil(f['stale'], '403 is transient — fact must NOT be marked stale')
  end

  def test_rescues_not_found_on_repo_name_lookup
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repositories/42', status: 404, body: { message: 'Not Found' })
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-merged', repository: 42, issue: 44, where: 'github')
    load_it('fix-missing-hoc', fb)
    assert(
      fb.one?(what: 'pull-was-merged', repository: 42, stale: 'repository'),
      'The fact of a vanished repository must be marked stale instead of aborting the judge'
    )
  end

  def test_dont_crash_when_pull_has_no_hoc
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/44',
      body: { id: 50, number: 44, state: 'closed', changed_files: 1 }
    )
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-merged', repository: 42, issue: 44, where: 'github')
    load_it('fix-missing-hoc', fb)
    assert_equal(
      0, fb.pick(issue: 44).hoc,
      'A pull request that reports no additions and no deletions cannot abort the judge'
    )
  end
end
