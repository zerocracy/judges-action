# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'judges/options'
require 'loog'
require_relative '../../lib/patches/unmask_repos'
require_relative '../test__helper'

class TestUnmaskReposExcluded < Jp::Test
  def test_drops_a_repository_the_mask_excludes
    rate_limit_up
    stub_github(
      'https://api.github.com/orgs/foo/repos?per_page=100&type=all',
      body: [{ full_name: 'foo/first' }, { full_name: 'foo/bar' }]
    )
    stub_github('https://api.github.com/repos/foo/first', body: { full_name: 'foo/first', archived: false })
    $loog = Loog::NULL
    assert_equal(
      ['foo/first'],
      Fbe.unmask_repos(
        options: Judges::Options.new({ 'repositories' => 'foo/*,-foo/bar' }), global: {}, loog: Loog::NULL
      ),
      'a repository excluded by a -mask cannot be yielded'
    )
  end
end
