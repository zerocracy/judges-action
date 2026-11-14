# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'loog'
require_relative '../../lib/patches/fake_octokit'
require_relative '../test__helper'

class TestFakeOctokit < Jp::Test
  def test_lists_milestones_of_a_repository
    $global = {}
    $options = Judges::Options.new({ 'testing' => true })
    $loog = Loog::NULL
    assert_empty(
      Fbe.octo.list_milestones('foo/foo', state: 'all'),
      'The milestones stub cannot refuse the options that judges send with it'
    )
  end

  def test_dates_releases_by_the_test_clock
    $global = {}
    $options = Judges::Options.new({ 'testing' => true })
    $loog = Loog::NULL
    prev = ENV.fetch('TODAY', nil)
    ENV['TODAY'] = '2025-10-11T00:00:00Z'
    moment = Time.parse(ENV.fetch('TODAY'))
    releases = Fbe.octo.releases('foo/foo')
    assert_equal(2, releases.size, 'The fake must serve two releases')
    assert(releases.none? { |r| r[:draft] }, 'The fake releases must not be drafts')
    assert(
      releases.all? { |r| r[:published_at] && r[:published_at] < moment },
      'The fake releases must be published before TODAY, so a judge window ending at TODAY can count them'
    )
  ensure
    ENV['TODAY'] = prev
  end
end
