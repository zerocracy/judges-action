# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

# Reproduction for hypothesis H4 (#131-class Forbidden bug verification).
# Proves dimensions-of-terrain (a metric judge) propagates Octokit::Forbidden
# unrescued when ANY repo in the configured list returns 403. The crash entry
# point is expected to be Fbe.unmask_repos warmup (lib/fbe/unmask_repos.rb:99)
# called from inside one of the total_*.rb helpers loaded by Jp.incremate.
# Lives on feature/forbidden-rescue-verification branch — NOT for upstream as-is.

require 'factbase'
require 'octokit'
require_relative '../test__helper'

class TestDimensionsOfTerrainForbidden < Jp::Test
  using SmartFactbase

  def test_dimensions_of_terrain_propagates_forbidden_on_repo_403
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github(
      'https://api.github.com/repos/foo/foo',
      body: {
        id: 42, full_name: 'foo/foo', name: 'foo', archived: false,
        default_branch: 'main', size: 100, stargazers_count: 1, forks: 0,
        open_issues_count: 0
      }
    )
    stub_github(
      'https://api.github.com/repos/foo/private',
      status: 403,
      body: { message: 'Resource not accessible by integration' }
    )
    fb = Factbase.new
    # Pre-seed a recent dim-of-terrain fact so the judge skips its insert path
    # and goes straight into Jp.incremate over the existing fact.
    fb.with(_id: 1, what: 'dimensions-of-terrain', when: Time.now)
    options = Judges::Options.new({ 'repositories' => 'foo/foo,foo/private' })
    exception = assert_raises(Octokit::Forbidden) do
      load_it('dimensions-of-terrain', fb, options)
    end
    assert_match(/Resource not accessible by integration/, exception.message)
  end

  def test_dimensions_of_terrain_aborts_before_any_metric_set
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github(
      'https://api.github.com/repos/foo/foo',
      body: {
        id: 42, full_name: 'foo/foo', name: 'foo', archived: false,
        default_branch: 'main', size: 100, stargazers_count: 1, forks: 0,
        open_issues_count: 0
      }
    )
    stub_github(
      'https://api.github.com/repos/foo/private',
      status: 403,
      body: { message: 'Resource not accessible by integration' }
    )
    fb = Factbase.new
    fb.with(_id: 1, what: 'dimensions-of-terrain', when: Time.now)
    options = Judges::Options.new({ 'repositories' => 'foo/foo,foo/private' })
    assert_raises(Octokit::Forbidden) do
      load_it('dimensions-of-terrain', fb, options)
    end
    fact = fb.query("(eq what 'dimensions-of-terrain')").each.first
    total_props = fact.all_properties.select { |p| p.to_s.start_with?('total_') }
    assert_empty(
      total_props,
      "Expected no total_* props (judge should abort before any helper completes), " \
      "but found: #{total_props.inspect}"
    )
  end
end
