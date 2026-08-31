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
end
