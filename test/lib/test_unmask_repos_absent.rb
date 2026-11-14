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

  def test_drops_a_renamed_repository
    rate_limit_up
    stub_request(:get, 'https://api.github.com/repos/cqfn/eo').to_return(
      status: 301,
      headers: { 'Content-Type' => 'application/json', 'Location' => 'https://api.github.com/repositories/73056727' },
      body: { message: 'Moved Permanently', url: 'https://api.github.com/repositories/73056727' }.to_json
    )
    stub_github('https://api.github.com/repos/foo/foo', body: { full_name: 'foo/foo', id: 42, archived: false })
    $loog = Loog::Buffer.new
    options = Judges::Options.new({ 'repositories' => 'cqfn/eo,foo/foo' })
    assert_equal(
      ['foo/foo'],
      Fbe.unmask_repos(options:, global: {}, loog: $loog),
      'a repository GitHub answers 301 for cannot be handed to the judges'
    )
    assert_includes($loog.to_s, 'Repository cqfn/eo has moved', $loog.to_s)
  end
end
