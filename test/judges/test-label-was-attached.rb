# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../test__helper'

class TestLabelWasAttached < Jp::Test
  using SmartFactbase

  def test_label_was_attached_with_duplicate_labeled_event
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, name: 'foo', full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/repos/foo/foo/issues/44/timeline?per_page=100',
      body: [
        {
          id: 195,
          actor: { id: 421, login: 'user' },
          event: 'labeled',
          created_at: '2025-09-30 06:14:38 UTC',
          label: { name: 'bug', color: 'd73a4a' }
        },
        {
          id: 196,
          actor: { id: 421, login: 'user' },
          event: 'labeled',
          created_at: '2025-09-30 06:14:39 UTC',
          label: { name: 'bug', color: 'd73a4a' }
        }
      ]
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/issues/45/timeline?per_page=100',
      status: 404,
      body: { message: 'Not Found', documentation_url: 'https://docs.github.com', status: '404' }
    )
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, issue: 44, where: 'github')
    fb.with(_id: 2, what: 'issue-was-opened', repository: 42, issue: 45, where: 'github')
    load_it('label-was-attached', fb)
    assert(fb.one?(what: 'label-was-attached', repository: 42, issue: 44, where: 'github', label: 'bug', who: 421))
    assert(fb.one?(what: 'issue-was-opened', repository: 42, issue: 45, where: 'github', stale: 'issue'))
  end

  def test_rescues_forbidden_on_timeline_lookup
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/repos/foo/foo/issues/44/timeline?per_page=100',
      status: 403,
      body: { message: 'Resource not accessible by integration' }
    )
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, issue: 44, where: 'github')
    load_it('label-was-attached', fb)
    f = fb.query('(eq issue 44)').each.first
    refute_nil(f)
    assert_nil(
      f['stale'],
      '403 is transient — fact must NOT be marked stale; next cycle will retry the timeline lookup'
    )
  end

  def test_attaches_each_tracked_label_and_ignores_others
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, name: 'foo', full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/repos/foo/foo/issues/44/timeline?per_page=100',
      body: [
        {
          id: 100, actor: { id: 421, login: 'alice' }, event: 'assigned',
          created_at: '2025-09-30 05:00:00 UTC'
        },
        {
          id: 101, actor: { id: 421, login: 'alice' }, event: 'labeled',
          created_at: '2025-09-30 06:00:00 UTC',
          label: { name: 'bug', color: 'd73a4a' }
        },
        {
          id: 102, actor: { id: 421, login: 'alice' }, event: 'labeled',
          created_at: '2025-09-30 06:10:00 UTC',
          label: { name: 'enhancement', color: 'a2eeef' }
        },
        {
          id: 103, actor: { id: 422, login: 'bob' }, event: 'labeled',
          created_at: '2025-09-30 06:20:00 UTC',
          label: { name: 'question', color: 'd876e3' }
        },
        {
          id: 104, actor: { id: 422, login: 'bob' }, event: 'labeled',
          created_at: '2025-09-30 06:30:00 UTC',
          label: { name: 'wontfix', color: 'ffffff' }
        }
      ]
    )
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, issue: 44, where: 'github')
    load_it('label-was-attached', fb)
    assert(fb.one?(what: 'label-was-attached', repository: 42, issue: 44, where: 'github', label: 'bug', who: 421))
    assert(
      fb.one?(what: 'label-was-attached', repository: 42, issue: 44, where: 'github', label: 'enhancement', who: 421)
    )
    assert(fb.one?(what: 'label-was-attached', repository: 42, issue: 44, where: 'github', label: 'question', who: 422))
    assert_equal(
      0,
      fb.query("(and (eq what 'label-was-attached') (eq label 'wontfix'))").each.to_a.size,
      'untracked labels (not bug/enhancement/question) must be ignored'
    )
  end

  def test_marks_stale_when_timeline_returns_not_found
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/repos/foo/foo/issues/44/timeline?per_page=100',
      status: 404,
      body: { message: 'Not Found', documentation_url: 'https://docs.github.com', status: '404' }
    )
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, issue: 44, where: 'github')
    load_it('label-was-attached', fb)
    assert(
      fb.one?(what: 'issue-was-opened', repository: 42, issue: 44, where: 'github', stale: 'issue'),
      '404 is permanent — issue must be marked stale via Jp.issue_was_lost'
    )
  end
end
