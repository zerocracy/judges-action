# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'judges/options'
require_relative '../test__helper'

class TestGithubEventsActor < Jp::Test
  def test_ignores_an_event_without_an_actor
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
    stub_github(
      'https://api.github.com/repositories/42/events?per_page=100',
      body: [
        {
          id: 14, created_at: Time.now.to_s,
          type: 'CreateEvent', repo: { id: 42, name: 'foo/foo' },
          payload: { ref_type: 'tag', ref: 'foo' }
        }
      ]
    )
    fb = Factbase.new
    load_it('github-events', fb, Judges::Options.new({ 'repositories' => 'foo/foo' }))
    assert_empty(
      fb.query("(eq what 'tag-was-created')").each.to_a,
      'an event with no actor cannot become a fact, since every later read assumes one'
    )
  end
end
