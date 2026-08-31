# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'judges/options'
require 'loog'
require_relative '../../lib/patches/unmask_repos'
require_relative '../test__helper'

class TestUnmaskRepos < Jp::Test
  def test_falls_back_to_user_repositories_when_organization_is_absent
    rate_limit_up
    stub_github('https://api.github.com/orgs/foo/repos?per_page=100&type=all', body: {}, status: 404)
    stub_github('https://api.github.com/users/foo/repos?per_page=100', body: [{ full_name: 'foo/first' }])
    stub_github('https://api.github.com/repos/foo/first', body: { full_name: 'foo/first', archived: false })
    $loog = Loog::NULL
    assert_equal(
      ['foo/first'],
      Fbe.unmask_repos(options: Judges::Options.new({ 'repositories' => 'foo/*' }), global: {}, loog: Loog::NULL),
      'repositories of a user cannot be lost when the organization is absent'
    )
  end

  def test_fetches_every_repository_once
    rate_limit_up
    stub = stub_github('https://api.github.com/repos/bar/bar', body: { full_name: 'bar/bar', archived: false })
    $loog = Loog::NULL
    Fbe.unmask_repos(options: Judges::Options.new({ 'repositories' => 'bar/bar' }), global: {}, loog: Loog::NULL)
    assert_requested(stub, times: 1, message: 'a repository cannot be fetched more than once per expansion')
  end

  def test_skips_the_mask_when_organization_listing_is_forbidden
    rate_limit_up
    stub_github('https://api.github.com/orgs/foo/repos?per_page=100&type=all', body: {}, status: 403)
    stub_github('https://api.github.com/repos/bar/bar', body: { full_name: 'bar/bar', archived: false })
    $loog = Loog::NULL
    assert_equal(
      ['bar/bar'],
      Fbe.unmask_repos(
        options: Judges::Options.new({ 'repositories' => 'foo/*,bar/bar' }), global: {}, loog: Loog::NULL
      ),
      'a forbidden organization cannot break the expansion of the other masks'
    )
  end

  def test_skips_the_mask_when_neither_organization_nor_user_exists
    rate_limit_up
    stub_github('https://api.github.com/orgs/foo/repos?per_page=100&type=all', body: {}, status: 404)
    stub_github('https://api.github.com/users/foo/repos?per_page=100', body: {}, status: 404)
    stub_github('https://api.github.com/repos/bar/bar', body: { full_name: 'bar/bar', archived: false })
    $loog = Loog::NULL
    assert_equal(
      ['bar/bar'],
      Fbe.unmask_repos(
        options: Judges::Options.new({ 'repositories' => 'foo/*,bar/bar' }), global: {}, loog: Loog::NULL
      ),
      'a mask pointing at nothing cannot break the expansion of the other masks'
    )
  end

  def test_skips_the_mask_when_github_fails_to_list_the_organization
    rate_limit_up
    stub_github('https://api.github.com/orgs/foo/repos?per_page=100&type=all', body: {}, status: 500)
    stub_github('https://api.github.com/repos/bar/bar', body: { full_name: 'bar/bar', archived: false })
    $loog = Loog::NULL
    assert_equal(
      ['bar/bar'],
      Fbe.unmask_repos(
        options: Judges::Options.new({ 'repositories' => 'foo/*,bar/bar' }), global: {}, loog: Loog::NULL
      ),
      'a server error cannot break the expansion of the other masks'
    )
  end
end
