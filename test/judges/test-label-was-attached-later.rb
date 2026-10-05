# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../test__helper'

class TestLabelWasAttachedLater < Jp::Test
  using SmartFactbase

  def test_sees_a_label_attached_after_the_first_scan
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, full_name: 'foo/foo' })
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/repos/foo/foo/issues/44/timeline?per_page=100',
      body: [
        {
          event: 'labeled', created_at: Time.parse('2025-05-01 10:00:00 UTC'),
          label: { name: 'question' }, actor: { id: 222_111, login: 'user1' }
        },
        {
          event: 'labeled', created_at: Time.parse('2025-05-02 10:00:00 UTC'),
          label: { name: 'bug' }, actor: { id: 222_111, login: 'user1' }
        }
      ]
    )
    stub_github('https://api.github.com/user/222111', body: { login: 'user1', id: 222_111 })
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, issue: 44, where: 'github')
      .with(
        _id: 2, what: 'label-was-attached', repository: 42, issue: 44, where: 'github',
        label: 'question', who: 222_111
      )
    load_it('label-was-attached', fb)
    assert(
      fb.one?(what: 'label-was-attached', repository: 42, issue: 44, where: 'github', label: 'bug'),
      'a label attached after the first scan must still be recorded'
    )
  end
end
