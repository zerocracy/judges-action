# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'judges/options'
require_relative '../test__helper'

class TestGithubEventsReleaseAuthor < Jp::Test
  def test_takes_the_author_of_the_release_not_the_actor
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github(
      'https://api.github.com/repos/foo/foo',
      body: { id: 42, name: 'foo', full_name: 'foo/foo', default_branch: 'master' }
    )
    stub_github(
      'https://api.github.com/repositories/42',
      body: { id: 42, name: 'foo', full_name: 'foo/foo', default_branch: 'master' }
    )
    stub_github('https://api.github.com/user/777', body: { id: 777, login: 'author' })
    stub_github('https://api.github.com/repos/foo/foo/contributors?per_page=100', body: [])
    stub_github('https://api.github.com/repos/foo/foo/commits?per_page=1', body: [{ sha: 'aa1122' }])
    stub_github(
      'https://api.github.com/repos/foo/foo/compare/aa1122...1.0.0?per_page=100',
      body: { total_commits: 1, commits: [{ sha: 'aa1122' }], files: [] }
    )
    stub_github(
      'https://api.github.com/repositories/42/events?per_page=100',
      body: [
        {
          id: 14, created_at: Time.now.to_s, actor: { id: 8_086_956 },
          type: 'ReleaseEvent', repo: { id: 42, name: 'foo/foo' },
          payload: {
            action: 'published',
            release: { id: 50, tag_name: '1.0.0', name: 'v1', author: { id: 777 } }
          }
        }
      ]
    )
    fb = Factbase.new
    load_it('github-events', fb, Judges::Options.new({ 'repositories' => 'foo/foo' }))
    f = fb.query("(eq what 'release-published')").each.first
    refute_nil(f, 'a published release must become a fact')
    assert_equal([777], f['who'], 'the author of the release must be written once, not appended next to the actor')
  end
end
