# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'judges/options'
require 'loog'
require_relative '../test__helper'

class TestFindAllPullsSearch < Jp::Test
  def test_searches_pulls_with_the_qualifier_github_knows
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 991 })
    stub_github('https://api.github.com/repositories/991', body: { full_name: 'foo/foo' })
    stub_github('https://api.github.com/repos/foo/foo/issues/45', body: { created_at: Time.parse('2025-05-04') })
    stub_github(
      'https://api.github.com/search/issues?per_page=100&q=repo:foo/foo%20type:pr%20created:%3E=2025-05-04',
      body: {
        total_count: 2, incomplete_results: false,
        items: [
          { number: 45, created_at: Time.parse('2025-05-04'), user: { id: 4242 } },
          { number: 46, created_at: Time.parse('2025-05-05'), user: { id: 4242 } }
        ]
      }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/46',
      body: { number: 46, head: { ref: 'feature/branch' } }
    )
    stub_github('https://api.github.com/user/4242', body: { login: 'yegor256' })
    fb = Factbase.new
    fb.insert.then do |f|
      f.issue = 45
      f.repository = 991
      f.what = 'pull-was-opened'
      f.where = 'github'
    end
    load_it('find-all-issues', fb)
    refute_empty(
      fb.query("(and (eq issue 46) (eq what 'pull-was-opened'))").each.to_a,
      'the pull search must use the type:pr qualifier'
    )
  end
end
