# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require_relative '../../lib/in_window_releases'
require_relative '../test__helper'

class TestInWindowReleases < Jp::Test
  def test_skips_too_new_and_yields_in_window_when_newest_is_past_when
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github(
      'https://api.github.com/repos/foo/foo/releases?per_page=100',
      body: [
        { tag_name: 'v3', published_at: Time.parse('2024-08-15 10:00:00 UTC') },
        { tag_name: 'v2', published_at: Time.parse('2024-08-05 10:00:00 UTC') },
        { tag_name: 'v1', published_at: Time.parse('2024-07-20 10:00:00 UTC') }
      ]
    )
    yielded = []
    $loog = Loog::NULL
    $options = Judges::Options.new('repositories' => 'foo/foo')
    $global = {}
    Jp.in_window_releases(
      'foo/foo',
      Time.parse('2024-08-01 00:00:00 UTC'),
      Time.parse('2024-08-10 00:00:00 UTC')
    ) do |r|
      yielded << r[:tag_name]
    end
    assert_equal(['v2'], yielded)
  end
end
