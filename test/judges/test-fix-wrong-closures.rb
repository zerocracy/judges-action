# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../test__helper'

class TestFixWrongClosures < Jp::Test
  using SmartFactbase

  def test_forgets_the_closure_of_a_merged_pull
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, full_name: 'foo/foo' })
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/55',
      body: {
        id: 50, number: 55, state: 'closed', merged: true,
        merged_at: Time.parse('2025-09-30 18:00:00 UTC'),
        head: { ref: '55', sha: 'aa123' }
      }
    )
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-closed', where: 'github', repository: 42, issue: 55, who: 44)
    load_it('fix-wrong-closures', fb)
    assert(
      fb.none?(what: 'pull-was-closed', where: 'github', repository: 42, issue: 55),
      'The closure of a merged pull cannot survive'
    )
  end

  def test_forgets_the_closure_of_a_reopened_pull
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, full_name: 'foo/foo' })
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/56',
      body: {
        id: 51, number: 56, state: 'open', merged: false, merged_at: nil,
        head: { ref: '56', sha: 'bb456' }
      }
    )
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-closed', where: 'github', repository: 42, issue: 56, who: 44)
    load_it('fix-wrong-closures', fb)
    assert(
      fb.none?(what: 'pull-was-closed', where: 'github', repository: 42, issue: 56),
      'The closure of a reopened pull cannot survive'
    )
  end

  def test_keeps_the_closure_of_a_pull_that_stays_closed
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, full_name: 'foo/foo' })
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/57',
      body: {
        id: 52, number: 57, state: 'closed', merged: false, merged_at: nil,
        head: { ref: '57', sha: 'cc789' }
      }
    )
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-closed', where: 'github', repository: 42, issue: 57, who: 44)
    load_it('fix-wrong-closures', fb)
    assert(
      fb.one?(what: 'pull-was-closed', where: 'github', repository: 42, issue: 57),
      'The closure of a pull that stays closed cannot be forgotten'
    )
  end

  def test_rescues_not_found_on_repo_name_lookup
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, name: 'foo', full_name: 'foo/foo' })
    stub_github('https://api.github.com/repositories/42', status: 404, body: { message: 'Not Found' })
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-closed', repository: 42, issue: 44, where: 'github')
    load_it('fix-wrong-closures', fb)
    assert(
      fb.one?(what: 'pull-was-closed', repository: 42, issue: 44),
      'A vanished repository must not delete the closure and must not abort the judge'
    )
  end

  def test_keeps_the_closure_when_repo_name_lookup_fails_with_server_error
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, full_name: 'foo/foo' })
    stub_github('https://api.github.com/repositories/42', status: 500, body: { message: 'Server Error' })
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-closed', where: 'github', repository: 42, issue: 58, who: 44)
    load_it('fix-wrong-closures', fb)
    assert(
      fb.one?(what: 'pull-was-closed', where: 'github', repository: 42, issue: 58),
      'The closure is lost after a server error on the repository lookup'
    )
  end

  def test_keeps_the_closure_when_repo_name_lookup_times_out
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, full_name: 'foo/foo' })
    stub_request(:get, 'https://api.github.com/repositories/42').to_timeout
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-closed', where: 'github', repository: 42, issue: 59, who: 44)
    load_it('fix-wrong-closures', fb)
    assert(
      fb.one?(what: 'pull-was-closed', where: 'github', repository: 42, issue: 59),
      'The closure is lost after a timeout on the repository lookup'
    )
  end

  def test_checks_the_next_pull_after_server_error_on_repo_name_lookup
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, full_name: 'foo/foo' })
    stub_github('https://api.github.com/repos/bar/bar', body: { id: 43, full_name: 'bar/bar' })
    stub_github('https://api.github.com/repositories/42', status: 502, body: { message: 'Bad Gateway' })
    stub_github('https://api.github.com/repositories/43', body: { id: 43, full_name: 'bar/bar' })
    stub_github(
      'https://api.github.com/repos/bar/bar/pulls/61',
      body: {
        id: 53, number: 61, state: 'open', merged: false, merged_at: nil,
        head: { ref: '61', sha: 'dd012' }
      }
    )
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-closed', where: 'github', repository: 42, issue: 60, who: 44)
    fb.with(_id: 2, what: 'pull-was-closed', where: 'github', repository: 43, issue: 61, who: 44)
    load_it('fix-wrong-closures', fb, Judges::Options.new({ 'repositories' => 'foo/foo,bar/bar' }))
    assert(
      fb.none?(what: 'pull-was-closed', where: 'github', repository: 43, issue: 61),
      'The judge stops before the next repository after a server error'
    )
  end
end
