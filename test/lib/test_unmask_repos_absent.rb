# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'judges/options'
require 'loog'
require_relative '../../lib/patches/unmask_repos'
require_relative '../test__helper'

class TestUnmaskReposAbsent < Jp::Test
  def test_drops_a_repository_that_is_not_found
    rate_limit_up
    stub_github(
      'https://api.github.com/repos/foo/gone',
      status: 404,
      body: { message: 'Not Found', documentation_url: 'https://docs.github.com', status: '404' }
    )
    stub_github('https://api.github.com/repos/foo/here', body: { full_name: 'foo/here', archived: false })
    $loog = Loog::NULL
    assert_equal(
      ['foo/here'],
      Fbe.unmask_repos(
        options: Judges::Options.new({ 'repositories' => 'foo/gone,foo/here' }), global: {}, loog: Loog::NULL
      ),
      'a repository GitHub answers 404 for cannot be handed to the judges'
    )
  end

  def test_drops_a_repository_blocked_for_legal_reasons
    rate_limit_up
    stub_github(
      'https://api.github.com/repos/foo/blocked',
      status: 451,
      body: { message: 'Repository access blocked', block: { reason: 'dmca' } }
    )
    stub_github('https://api.github.com/repos/foo/here', body: { full_name: 'foo/here', archived: false })
    $loog = Loog::Buffer.new
    assert_equal(
      ['foo/here'],
      Fbe.unmask_repos(
        options: Judges::Options.new({ 'repositories' => 'foo/blocked,foo/here' }), global: {}, loog: $loog
      ),
      'a repository GitHub answers 451 for cannot be handed to the judges'
    )
    assert_includes($loog.to_s, 'Repository foo/blocked is blocked for legal reasons, dropping it', $loog.to_s)
  end
end
