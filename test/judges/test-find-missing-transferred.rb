# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../test__helper'

class TestFindMissingTransferred < Jp::Test
  using SmartFactbase

  def test_does_not_record_a_different_issue_number
    scan(issue(12, 'other/project'))
  end

  def test_does_not_record_the_same_number_in_another_repository
    scan(issue(45, 'other/project'))
  end

  def test_handles_a_redirect_with_or_without_a_response_body
    scan(issue(12, 'other/project'), redirect: true)
  end

  def test_handles_a_nil_response
    scan(nil)
  end

  def test_handles_an_empty_response
    scan('')
  end

  def test_handles_a_nonempty_string_response
    scan('unexpected response')
  end

  def test_handles_an_array_response
    scan([])
  end

  private

  def issue(number, repository)
    {
      number:, repository_url: "https://api.github.com/repos/#{repository}",
      user: { id: 44, login: 'user' }, created_at: '2025-09-27 06:03:16 UTC'
    }
  end

  def scan(response, redirect: false)
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    address = 'https://api.github.com/repos/foo/foo/issues/45'
    if redirect
      moved = 'https://api.github.com/repos/other/project/issues/12'
      stub_request(:get, address).to_return(status: 301, body: '', headers: { 'Location' => moved })
      stub_github(moved, body: response)
    else
      stub_github(address, body: response)
    end
    stub_github('https://api.github.com/repos/foo/foo/issues/46', body: issue(46, 'FOO/Foo'))
    stub_github('https://api.github.com/user/44', body: { id: 44, login: 'user' })
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, issue: 44, where: 'github')
      .with(_id: 2, what: 'issue-was-opened', repository: 42, issue: 47, where: 'github')
    load_it('find-missing-issues', fb)
    assert(fb.one?(what: 'issue-was-lost', repository: 42, issue: 45, stale: 'issue'))
    assert(fb.one?(what: 'tombstone', repository: 42, issues: '45'))
    assert(fb.one?(what: 'issue-was-opened', repository: 42, issue: 46))
    assert_equal([44, 46, 47], fb.picks(what: 'issue-was-opened').map(&:issue).sort!)
    load_it('find-missing-issues', fb)
    assert_requested(:get, address, times: 1)
  end
end
