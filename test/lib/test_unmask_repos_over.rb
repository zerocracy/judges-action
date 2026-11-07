# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'judges/options'
require 'loog'
require 'minitest/mock'
require_relative '../../lib/patches/unmask_repos'
require_relative '../test__helper'

class TestUnmaskReposOver < Jp::Test
  def test_stops_yielding_once_the_time_is_up
    rate_limit_up
    stub_github('https://api.github.com/repos/foo/first', body: { full_name: 'foo/first', archived: false })
    $loog = Loog::NULL
    asked = 0
    over =
      lambda do |**|
        asked += 1
        asked > 1
      end
    yielded = []
    Fbe.stub(:over?, over) do
      Fbe.unmask_repos(
        options: Judges::Options.new({ 'repositories' => 'foo/first' }), global: {}, loog: Loog::NULL
      ) { |repo| yielded << repo }
    end
    assert_empty(yielded, 'no repository can be yielded once the lifetime is spent')
  end
end
