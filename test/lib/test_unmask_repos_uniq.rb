# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'judges/options'
require 'loog'
require_relative '../../lib/patches/unmask_repos'
require_relative '../test__helper'

class TestUnmaskReposUniq < Jp::Test
  def test_yields_a_pinned_repository_once
    rate_limit_up
    stub_github(
      'https://api.github.com/orgs/foo/repos?per_page=100&type=all',
      body: [{ full_name: 'foo/first' }, { full_name: 'foo/second' }]
    )
    stub_github('https://api.github.com/repos/foo/first', body: { full_name: 'foo/first', archived: false })
    stub_github('https://api.github.com/repos/foo/second', body: { full_name: 'foo/second', archived: false })
    $loog = Loog::NULL
    assert_equal(
      %w[foo/first foo/second],
      Fbe.unmask_repos(
        options: Judges::Options.new({ 'repositories' => 'foo/*,foo/first' }), global: {}, loog: Loog::NULL
      ).sort,
      'a repository matched by a wildcard and pinned by name cannot appear twice'
    )
  end
end
