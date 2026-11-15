# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../test__helper'

class TestLabelEvent < Jp::Test
  using SmartFactbase

  def test_does_not_attach_a_removed_label
    assert_empty(scan('unlabeled').picks(what: 'label-was-attached'), 'removing a label must not attach it')
  end

  def test_records_the_timeline_event_time
    fact = scan('labeled').pick(what: 'label-was-attached')
    assert_equal(Time.utc(2025, 9, 30, 6, 14, 38), fact.when, 'attachment time must come from the timeline event')
  end

  private

  def scan(event)
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/repos/foo/foo/issues/44/timeline?per_page=100',
      body: [
        {
          id: 195, actor: { id: 421, login: 'user' }, event:,
          created_at: '2025-09-30 06:14:38 UTC', label: { name: 'bug', color: 'd73a4a' }
        }
      ]
    )
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, issue: 44, where: 'github')
    load_it('label-was-attached', fb)
    fb
  end
end
