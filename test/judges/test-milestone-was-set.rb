# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../test__helper'

class TestMilestoneWasSet < Jp::Test
  using SmartFactbase

  def test_finds_milestones
    WebMock.disable_net_connect!
    rate_limit_up
    repo
    milestones(
      [
        {
          number: 7,
          title: 'v1.0',
          creator: { id: 444, login: 'jeff' },
          created_at: '2026-01-02 03:04:05 UTC',
          due_on: '2026-02-03 00:00:00 UTC'
        }
      ]
    )
    stub_github('https://api.github.com/user/444', body: { id: 444, login: 'jeff' })
    fb = Factbase.new
    load_it('milestone-was-set', fb)
    assert(
      fb.one?(
        what: 'milestone-was-set',
        where: 'github',
        repository: 42,
        milestone: 7,
        who: 444,
        when: Time.parse('2026-01-02 03:04:05 UTC'),
        deadline: Time.parse('2026-02-03 00:00:00 UTC'),
        details: 'The milestone #7 in foo/foo was set by @jeff.'
      )
    )
    assert(fb.one?(what: 'iterate', milestones_were_scanned: 7, repository: 42, where: 'github'))
  end

  def test_skips_existing_milestones_and_advances_cursor
    WebMock.disable_net_connect!
    rate_limit_up
    repo
    milestones(
      [
        { number: 1, creator: { id: 111 }, created_at: '2026-01-01 00:00:00 UTC', due_on: nil },
        { number: 2, creator: { id: 222 }, created_at: '2026-01-02 00:00:00 UTC', due_on: nil },
        { number: 3, creator: { id: 333 }, created_at: '2026-01-03 00:00:00 UTC', due_on: nil }
      ]
    )
    stub_github('https://api.github.com/user/333', body: { id: 333, login: 'third' })
    fb = Factbase.new
    fb.with(
      _id: 1,
      what: 'milestone-was-set',
      where: 'github',
      repository: 42,
      milestone: 2,
      who: 222,
      when: Time.parse('2026-01-02 00:00:00 UTC')
    ).with(_id: 2, what: 'iterate', where: 'github', repository: 42, milestones_were_scanned: 2)
    load_it('milestone-was-set', fb)
    assert_equal(2, fb.picks(what: 'milestone-was-set').size)
    assert(fb.one?(what: 'milestone-was-set', repository: 42, milestone: 3, who: 333))
    assert(fb.one?(what: 'iterate', milestones_were_scanned: 3, repository: 42, where: 'github'))
  end

  def test_marks_absent_creator_as_stale
    WebMock.disable_net_connect!
    rate_limit_up
    repo
    milestones(
      [
        {
          number: 5,
          title: 'unknown owner',
          creator: nil,
          created_at: '2026-01-05 00:00:00 UTC',
          due_on: nil
        }
      ]
    )
    fb = Factbase.new
    load_it('milestone-was-set', fb)
    assert(fb.one?(what: 'milestone-was-set', repository: 42, milestone: 5, stale: 'who'))
    assert_nil(fb.pick(what: 'milestone-was-set', milestone: 5)['deadline'])
  end

  def test_forbidden_milestones_are_transient
    WebMock.disable_net_connect!
    rate_limit_up
    repo
    stub_github(
      %r{https://api[.]github[.]com/repos/foo/foo/milestones},
      status: 403,
      body: { message: 'Resource not accessible by integration' }
    )
    fb = Factbase.new
    load_it('milestone-was-set', fb)
    assert_empty(fb.picks(what: 'milestone-was-set'))
    assert_empty(fb.picks(what: 'iterate'))
  end

  private

  def repo
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, name: 'foo', full_name: 'foo/foo' })
    stub_github('https://api.github.com/repositories/42', body: { id: 42, name: 'foo', full_name: 'foo/foo' })
  end

  def milestones(body)
    stub_github(%r{https://api[.]github[.]com/repos/foo/foo/milestones}, body: body)
  end
end
