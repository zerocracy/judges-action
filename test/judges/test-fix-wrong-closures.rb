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

  def test_skips_a_pull_whose_lookup_times_out
    rackenv = ENV.fetch('RACK_ENV', nil)
    ENV['RACK_ENV'] = 'test'
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, full_name: 'foo/foo' })
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_request(:get, 'https://api.github.com/repos/foo/foo/pulls/58').to_raise(Net::ReadTimeout)
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/59',
      body: { id: 53, number: 59, state: 'closed', merged: true, merged_at: Time.parse('2025-10-01 09:00:00 UTC') }
    )
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-closed', where: 'github', repository: 42, issue: 58, who: 44)
    fb.with(_id: 2, what: 'pull-was-closed', where: 'github', repository: 42, issue: 59, who: 44)
    load_it('fix-wrong-closures', fb)
    assert(
      fb.none?(what: 'pull-was-closed', where: 'github', repository: 42, issue: 59),
      'A read timeout on one pull cannot stop the judge before the next merged pull'
    )
  ensure
    rackenv.nil? ? ENV.delete('RACK_ENV') : ENV['RACK_ENV'] = rackenv
  end

  def test_skips_a_pull_whose_connection_resets
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, full_name: 'foo/foo' })
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_request(:get, 'https://api.github.com/repos/foo/foo/pulls/60').to_raise(Errno::ECONNRESET)
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/61',
      body: { id: 54, number: 61, state: 'open', merged: false, merged_at: nil }
    )
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-closed', where: 'github', repository: 42, issue: 60, who: 44)
    fb.with(_id: 2, what: 'pull-was-closed', where: 'github', repository: 42, issue: 61, who: 44)
    load_it('fix-wrong-closures', fb)
    assert(
      fb.none?(what: 'pull-was-closed', where: 'github', repository: 42, issue: 61),
      'A connection reset on one pull cannot stop the judge before the next reopened pull'
    )
  end

  def test_keeps_the_closure_of_a_pull_whose_host_is_unresolvable
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, full_name: 'foo/foo' })
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_request(:get, 'https://api.github.com/repos/foo/foo/pulls/62').to_raise(SocketError)
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-closed', where: 'github', repository: 42, issue: 62, who: 44)
    load_it('fix-wrong-closures', fb)
    assert(
      fb.one?(what: 'pull-was-closed', where: 'github', repository: 42, issue: 62),
      'An unresolvable host cannot delete the closure of a pull it failed to fetch'
    )
  end
end
