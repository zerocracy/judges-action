# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../test__helper'

# Test.
class TestMilestoneWasSet < Jp::Test
  using SmartFactbase

  def test_find_absent_milestone_was_set_facts
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/repos/foo/foo/milestones?state=all&per_page=100',
      body: [
        {
          id: 1001,
          number: 333,
          title: 'Release v1.0',
          description: 'First major release',
          state: 'open',
          created_at: Time.parse('2024-01-01 10:00:00 UTC'),
          updated_at: Time.parse('2024-01-01 10:00:00 UTC'),
          due_on: Time.parse('2025-03-03 23:59:59 UTC'),
          creator: { id: 888, login: 'project-lead' }
        },
        {
          id: 1002,
          number: 334,
          title: 'Beta Testing',
          description: 'Complete beta testing phase',
          state: 'closed',
          created_at: Time.parse('2024-02-01 09:00:00 UTC'),
          updated_at: Time.parse('2024-04-01 14:30:00 UTC'),
          closed_at: Time.parse('2024-04-01 14:30:00 UTC'),
          due_on: Time.parse('2024-03-31 23:59:59 UTC'),
          creator: { id: 889, login: 'qa-manager' }
        }
      ]
    )
    stub_github('https://api.github.com/user/888', body: { id: 888, login: 'project-lead' })
    stub_github('https://api.github.com/user/889', body: { id: 889, login: 'qa-manager' })
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-closed', repository: 42, issue: 40, where: 'github')
      .with(_id: 2, what: 'milestone-was-set', repository: 42, milestone: 332, where: 'github')
      .with(_id: 3, what: 'milestone-was-closed', repository: 42, milestone: 331, where: 'github')
    load_it('milestone-was-set', fb)
    assert_equal(5, fb.all.size)
    assert(
      fb.one?(
        what: 'milestone-was-set',
        where: 'github',
        repository: 42,
        milestone: 333,
        who: 888,
        when: Time.parse('2024-01-01 10:00:00 UTC'),
        deadline: Time.parse('2025-03-03 23:59:59 UTC'),
        title: 'Release v1.0',
        description: 'First major release',
        details: 'A new milestone #333 \'Release v1.0\' has been set in foo/foo by @project-lead with deadline 2025-03-03 23:59:59 UTC.'
      )
    )
    assert(
      fb.one?(
        what: 'milestone-was-closed',
        where: 'github',
        repository: 42,
        milestone: 334,
        who: 889,
        when: Time.parse('2024-02-01 09:00:00 UTC'),
        closed_at: Time.parse('2024-04-01 14:30:00 UTC'),
        title: 'Beta Testing',
        description: 'Complete beta testing phase',
        details: 'The milestone #334 \'Beta Testing\' has been closed in foo/foo by @qa-manager.'
      )
    )
  end

  def test_skip_already_processed_milestones
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/repos/foo/foo/milestones?state=all&per_page=100',
      body: [
        {
          id: 1001,
          number: 333,
          title: 'Release v1.0',
          description: 'First major release',
          state: 'open',
          created_at: Time.parse('2024-01-01 10:00:00 UTC'),
          updated_at: Time.parse('2024-01-01 10:00:00 UTC'),
          due_on: Time.parse('2025-03-03 23:59:59 UTC'),
          creator: { id: 888, login: 'project-lead' }
        }
      ]
    )
    stub_github('https://api.github.com/user/888', body: { id: 888, login: 'project-lead' })
    fb = Factbase.new
    fb.with(
      _id: 1,
      what: 'milestone-was-set',
      repository: 42,
      milestone: 333,
      where: 'github',
      milestone_event_id: '42-333-1704105600'
    )
    load_it('milestone-was-set', fb)
    assert_equal(1, fb.all.size)
  end

  def test_milestone_without_deadline
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/repos/foo/foo/milestones?state=all&per_page=100',
      body: [
        {
          id: 1001,
          number: 335,
          title: 'Backlog Grooming',
          description: 'Regular backlog maintenance',
          state: 'open',
          created_at: Time.parse('2024-01-15 14:00:00 UTC'),
          updated_at: Time.parse('2024-01-15 14:00:00 UTC'),
          due_on: nil,
          creator: { id: 890, login: 'scrum-master' }
        }
      ]
    )
    stub_github('https://api.github.com/user/890', body: { id: 890, login: 'scrum-master' })
    fb = Factbase.new
    load_it('milestone-was-set', fb)
    assert_equal(1, fb.all.size)
    milestone_fact = fb.query("(eq milestone 335)").each.first
    assert_equal('milestone-was-set', milestone_fact.what)
    assert_nil(milestone_fact.deadline)
    assert_includes(milestone_fact.details, 'without a deadline')
  end
end