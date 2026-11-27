# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../../lib/pull_request'
require_relative '../fake_github'
require_relative '../test__helper'

class TestGithubEventKnownClosure < Jp::Test
  using SmartFactbase

  def test_does_not_fetch_comments_for_a_known_merge
    scan('pull-was-merged', '2025-06-27T19:00:05Z')
  end

  def test_does_not_fetch_comments_for_a_known_closure
    scan('pull-was-closed', nil)
  end

  private

  def scan(what, merged)
    fb = Factbase.new
    fb.with(what:, where: 'github', repository: 42, issue: 123, event_id: 10)
    event = {
      id: 11, type: 'PullRequestEvent', actor: { id: 45 }, repo: { id: 42 },
      created_at: '2025-06-27T19:00:05Z', payload: { action: 'closed', pull_request: { number: 123 } }
    }
    Jp::FakeGithub.new(
      'GET /rate_limit' => { rate: { remaining: 1000, limit: 1000 } },
      'GET /repos/foo/foo' => { id: 42, full_name: 'foo/foo' },
      'GET /repositories/42' => { id: 42, full_name: 'foo/foo' },
      'GET /repositories/42/events?per_page=100' => [event],
      'GET /repos/foo/foo/pulls/123' => { number: 123, merged_at: merged }
    ).run do
      Jp.stub(:comments_info, ->(*) { flunk('an existing closure must not fetch its comments again') }) do
        load_it('github-events', fb)
      end
    end
    assert(fb.one?(what:, repository: 42, issue: 123), 'the recorded closure must remain unique')
    assert(fb.one?(what: 'iterate', events_were_scanned: 11), 'the scan must advance past the duplicate event')
  end
end
