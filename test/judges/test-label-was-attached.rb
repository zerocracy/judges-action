# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../test__helper'

# Test.
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

    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, issue: 44, where: 'github')
    load_it('label-was-attached', fb)
    assert(
      fb.one?(what: 'label-was-attached', repository: 42, issue: 44, where: 'github', label: 'bug', who: 421)
    )
  end
end
