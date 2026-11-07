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
    bar = stub_github('https://api.github.com/orgs/bar/repos?per_page=100&type=all', body: [{ full_name: 'bar/bar' }])
    archived = stub_github('https://api.github.com/repos/bar/bar', body: { full_name: 'bar/bar', archived: false })
    $loog = Loog::NULL
    assert_empty(
      Fbe.unmask_repos(
        options: Judges::Options.new({ 'repositories' => 'foo/*,bar/*' }), global: {}, loog: Loog::NULL
      ),
      'a forbidden organization must report an incomplete expansion, not a shorter list'
    )
    assert_requested(bar, times: 1, message: 'the other masks must still be expanded')
    assert_not_requested(archived)
  end

  def test_skips_the_mask_when_neither_organization_nor_user_exists
    rate_limit_up
    stub_github('https://api.github.com/orgs/foo/repos?per_page=100&type=all', body: {}, status: 404)
    stub_github('https://api.github.com/users/foo/repos?per_page=100', body: {}, status: 404)
    bar = stub_github('https://api.github.com/orgs/bar/repos?per_page=100&type=all', body: [{ full_name: 'bar/bar' }])
    archived = stub_github('https://api.github.com/repos/bar/bar', body: { full_name: 'bar/bar', archived: false })
    $loog = Loog::NULL
    assert_empty(
      Fbe.unmask_repos(
        options: Judges::Options.new({ 'repositories' => 'foo/*,bar/*' }), global: {}, loog: Loog::NULL
      ),
      'a mask pointing at nothing must report an incomplete expansion, not a shorter list'
    )
    assert_requested(bar, times: 1, message: 'the other masks must still be expanded')
    assert_not_requested(archived)
  end

  def test_skips_the_mask_when_github_fails_to_list_the_organization
    rate_limit_up
    stub_github('https://api.github.com/orgs/foo/repos?per_page=100&type=all', body: {}, status: 500)
    bar = stub_github('https://api.github.com/orgs/bar/repos?per_page=100&type=all', body: [{ full_name: 'bar/bar' }])
    archived = stub_github('https://api.github.com/repos/bar/bar', body: { full_name: 'bar/bar', archived: false })
    $loog = Loog::NULL
    assert_empty(
      Fbe.unmask_repos(
        options: Judges::Options.new({ 'repositories' => 'foo/*,bar/*' }), global: {}, loog: Loog::NULL
      ),
      'a server error must report an incomplete expansion, not a shorter list'
    )
    assert_requested(bar, times: 1, message: 'the other masks must still be expanded')
    assert_not_requested(archived)
  end

  def test_does_not_yield_the_partial_list_when_a_mask_is_skipped
    rate_limit_up
    stub_github('https://api.github.com/orgs/foo/repos?per_page=100&type=all', body: {}, status: 500)
    stub_github('https://api.github.com/orgs/bar/repos?per_page=100&type=all', body: [{ full_name: 'bar/bar' }])
    archived = stub_github('https://api.github.com/repos/bar/bar', body: { full_name: 'bar/bar', archived: false })
    $loog = Loog::NULL
    yielded = []
    result =
      Fbe.unmask_repos(
        options: Judges::Options.new({ 'repositories' => 'foo/*,bar/*' }), global: {}, loog: Loog::NULL
      ) { |repo| yielded << repo }
    assert_empty(result, 'the block form must report the skipped mask too')
    assert_empty(yielded, 'a partial list must not be handed to the block')
    assert_not_requested(archived)
  end

  def test_raises_when_a_complete_expansion_matches_nothing
    rate_limit_up
    stub_github('https://api.github.com/orgs/foo/repos?per_page=100&type=all', body: [{ full_name: 'foo/first' }])
    stub_github('https://api.github.com/repos/foo/first', body: { full_name: 'foo/first', archived: true })
    $loog = Loog::NULL
    error =
      assert_raises(Fbe::Error) do
        Fbe.unmask_repos(options: Judges::Options.new({ 'repositories' => 'foo/*' }), global: {}, loog: Loog::NULL)
      end
    assert_includes(
      error.message, 'No repos found matching',
      'a complete expansion that matched nothing is a config error'
    )
  end
end
