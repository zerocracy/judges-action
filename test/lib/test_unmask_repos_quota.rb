# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'judges/options'
require 'loog'
require_relative '../../lib/patches/unmask_repos'
require_relative '../test__helper'

class TestUnmaskReposQuota < Jp::Test
  def test_skips_a_mask_when_the_quota_runs_out
    quota_short
    $loog = Loog::NULL
    error =
      assert_raises(Fbe::Error) do
        Fbe.unmask_repos(options: Judges::Options.new({ 'repositories' => 'foo/*' }), global: {}, loog: Loog::NULL)
      end
    assert_equal(
      'No repos found matching: "foo/*"', error.message,
      'a spent quota skips the mask instead of killing the run with OffQuota'
    )
  end

  def test_keeps_a_repository_when_the_quota_runs_out
    quota_short
    $loog = Loog::NULL
    assert_equal(
      %w[foo/a foo/b],
      Fbe.unmask_repos(
        options: Judges::Options.new({ 'repositories' => 'foo/a,foo/b' }), global: {}, loog: Loog::NULL
      ).sort,
      'a spent quota cannot drop a repository as if it were archived'
    )
  end

  private

  def quota_short
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      body: { resources: { search: { remaining: 30, limit: 30 } }, rate: { remaining: 40, limit: 1000 } }.to_json,
      headers: { 'Content-Type': 'application/json', 'X-RateLimit-Remaining' => '40' }
    )
  end
end
