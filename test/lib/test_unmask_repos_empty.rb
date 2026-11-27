# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'judges/options'
require 'loog'
require_relative '../../lib/patches/unmask_repos'
require_relative '../test__helper'

class TestUnmaskReposEmpty < Jp::Test
  def test_refuses_a_mask_that_matches_nothing
    rate_limit_up
    stub_github('https://api.github.com/orgs/foo/repos?per_page=100&type=all', body: [])
    $loog = Loog::NULL
    e =
      assert_raises(Fbe::Error, 'a mask matching no repository cannot pass silently') do
        Fbe.unmask_repos(options: Judges::Options.new({ 'repositories' => 'foo/*' }), global: {}, loog: Loog::NULL)
      end
    assert_match(%r{No repos found matching: "foo/\*"}, e.message)
  end
end
